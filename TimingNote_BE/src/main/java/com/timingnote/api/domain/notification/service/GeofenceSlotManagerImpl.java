package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceSlotRecalculateEvent;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.repository.projection.TodoCandidateDistanceProjection;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeofenceSlotManagerImpl implements GeofenceSlotManager {

    // 동시에 활성화할 Geofence 슬롯 상한.
    // iOS/Android의 지역 모니터링 한도를 고려해 18개로 제한한다.
    private static final int ACTIVE_SLOT_LIMIT = 18;
    // 거리 점수 가중치: 가까운 장소를 우선하기 위한 비중.
    private static final double DISTANCE_WEIGHT = 0.7;
    // 진행 방향(course) 점수 가중치: 사용자가 이동하는 방향에 있는 장소를 우대한다.
    private static final double HEADING_WEIGHT = 0.3;
    // user_places(사용자 등록 장소)와 일치할 때 주는 보너스 점수.
    // 별칭/자주 가는 장소를 후보 상위로 올리기 위한 가산점이다.
    private static final double USER_PLACE_BONUS = 0.15;

    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final GeofenceSlotRepository geofenceSlotRepository;
    private final UserPlaceRepository userPlaceRepository;
    private final GeofenceSlotSseService geofenceSlotSseService;

    @Override
    @Transactional
    public void recalculateSlots(GeofenceSlotRecalculateEvent event) {
        // 이벤트 필수값 검증:
        // userId가 없으면 어떤 사용자 슬롯을 갱신해야 할지 알 수 없으므로 종료한다.
        if (event == null || event.userId() == null) {
            log.warn("Skip geofence slot recalculation because event is invalid");
            return;
        }

        OffsetDateTime now = OffsetDateTime.now();
        // 사용자 등록 장소(user_places)의 place_id 집합을 미리 구성한다.
        // 이후 후보 점수 계산에서 alias 보너스 판정에 사용한다.
        Set<Long> userPlaceIds = userPlaceRepository.findWithPlaceByUserId(event.userId()).stream()
                .map(UserPlace::getPlace)
                .map(Place::getId)
                .collect(HashSet::new, HashSet::add, HashSet::addAll);

        List<TodoCandidatePlace> rawCandidates;
        Map<Long, Double> postgisDistanceByCandidateId = new HashMap<>();
        //후보 장소 목록 찾기
        if (event.latitude() != null && event.longitude() != null) {
            List<TodoCandidateDistanceProjection> distanceRows =
                    todoCandidatePlaceRepository.findMonitoringCandidateDistancesByUserId(
                            event.userId(),
                            event.latitude().doubleValue(),
                            event.longitude().doubleValue()
                    );
            List<Long> candidateIds = new ArrayList<>();
            for (TodoCandidateDistanceProjection row : distanceRows) {
                candidateIds.add(row.getCandidateId());
                postgisDistanceByCandidateId.put(row.getCandidateId(), row.getDistanceMeters());
            }
            rawCandidates = candidateIds.isEmpty()
                    ? List.of()
                    : todoCandidatePlaceRepository.findAllWithTodoAndPlaceByIdIn(candidateIds);
        } else {
            // 위치 좌표가 없으면 기존 candidate distance_m을 fallback으로 사용한다.
            rawCandidates = todoCandidatePlaceRepository.findMonitoringCandidatesByUserId(event.userId());
        }
        // 하드 규칙 필터 -> 점수 계산(거리/방향/alias 보너스) -> 내림차순 정렬
        List<ScoredCandidate> scored = rawCandidates.stream()
                .filter(this::passesHardRules)
                .map(candidate -> scoreCandidate(
                        candidate,
                        event.latitude(),
                        event.longitude(),
                        event.course(),
                        userPlaceIds,
                        postgisDistanceByCandidateId
                ))
                .sorted(Comparator.comparingDouble(ScoredCandidate::score).reversed())
                .toList();

        // 상위 N개(top 18)만 활성 슬롯으로 선정한다.
        Set<SlotIdentity> activeKeys = new HashSet<>();
        int activeCount = Math.min(ACTIVE_SLOT_LIMIT, scored.size());
        for (int i = 0; i < activeCount; i++) {
            activeKeys.add(scored.get(i).identity());
        }

        // 기존 슬롯을 (todoId, placeId) 키로 맵핑해 upsert 준비.
        List<GeofenceSlot> existing = geofenceSlotRepository.findByUserId(event.userId());
        Map<SlotIdentity, GeofenceSlot> existingByKey = new HashMap<>();
        for (GeofenceSlot slot : existing) {
            existingByKey.put(new SlotIdentity(slot.getTodoId(), slot.getPlaceId()), slot);
        }

        for (ScoredCandidate candidate : scored) {
            // top 18에 포함되면 active=true, 아니면 active=false.
            boolean shouldActive = activeKeys.contains(candidate.identity());
            geofenceSlotRepository.upsertSlot(
                    event.userId(),
                    candidate.placeId(),
                    candidate.todoId(),
                    now,
                    shouldActive
            );
        }

        // 이번 후보군에 아예 없는 기존 슬롯은 강제로 비활성화한다.
        // (과거에는 후보였지만 지금은 제외된 케이스 정리)
        List<GeofenceSlot> toSave = new ArrayList<>();
        for (GeofenceSlot slot : existing) {
            SlotIdentity identity = new SlotIdentity(slot.getTodoId(), slot.getPlaceId());
            if (activeKeys.contains(identity)) {
                continue;
            }
            if (existingByKey.containsKey(identity) && !containsSlotIdentity(scored, identity)) {
                slot.refresh(slot.getPlaceId(), slot.getTodoId(), now, false);
                toSave.add(slot);
            }
        }

        if (!toSave.isEmpty()) {
            geofenceSlotRepository.saveAll(toSave);
        }
        geofenceSlotSseService.notifySlotsUpdated(event.userId(), now);
        log.info("Recalculated geofence slots. userId={} candidates={} active={}", event.userId(), scored.size(), activeCount);
    }

    private boolean containsSlotIdentity(List<ScoredCandidate> scored, SlotIdentity slotIdentity) {
        for (ScoredCandidate candidate : scored) {
            if (candidate.identity().equals(slotIdentity)) {
                return true;
            }
        }
        return false;
    }

    private boolean passesHardRules(TodoCandidatePlace candidatePlace) {
        // 하드 규칙:
        // 1) alert_enabled=false 이면 후보 제외
        // 2) snooze 기간이 아직 끝나지 않았으면 제외
        Todo todo = candidatePlace.getTodo();
        if (todo == null || !todo.isAlertEnabled()) {
            return false;
        }
        OffsetDateTime now = OffsetDateTime.now();
        return todo.getSnoozedUntil() == null || !todo.getSnoozedUntil().isAfter(now);
    }

    //후보 점수 계산
    private ScoredCandidate scoreCandidate(
            TodoCandidatePlace candidatePlace,
            BigDecimal latitude,
            BigDecimal longitude,
            BigDecimal course,
            Set<Long> userPlaceIds,
            Map<Long, Double> postgisDistanceByCandidateId
    ) {
        // 거리 계산:
        // 1) lat/lon가 있으면 실시간 하버사인 거리 사용
        // 2) 없으면 todo_candidate_places.distance_m(기계산 값) 사용
        Place place = candidatePlace.getPlace();
        double distanceMeters;
        if (latitude != null && longitude != null) {
            // PostGIS ST_Distance 결과를 사용한다.
            distanceMeters = postgisDistanceByCandidateId.getOrDefault(
                    candidatePlace.getId(),
                    (double) candidatePlace.getDistanceM()
            );
        } else {
            distanceMeters = candidatePlace.getDistanceM();
        }

        // 거리 점수:
        // 거리가 멀수록 작아지는 단순 감쇠 함수(1 / (1 + d)).
        double distanceScore = 1.0 / (1.0 + distanceMeters);
        // lat/lon 또는 course가 없으면 방향 점수는 0으로 둔다(거리 중심 동작).
        double headingScore = 0.0;

        if (course != null && latitude != null && longitude != null) {
            // 현재 위치에서 후보 장소를 바라보는 방위각(bearing)을 구한 뒤,
            // 사용자 course와의 각도 차이를 cos 기반으로 [0,1] 점수화한다.
            // - 정면(0도 차이)일수록 1
            // - 반대(180도 차이)일수록 0
            double bearingToPlace = bearingDegrees(
                    latitude.doubleValue(),
                    longitude.doubleValue(),
                    place.getLatitude(),
                    place.getLongitude()
            );
            double diff = angularDifference(course.doubleValue(), bearingToPlace);
            headingScore = (Math.cos(Math.toRadians(diff)) + 1.0) / 2.0;
        }

        // user_places에 등록된 장소면 보너스 가산.
        double aliasBonus = userPlaceIds.contains(place.getId()) ? USER_PLACE_BONUS : 0.0;
        // 최종 점수 = 거리 + 방향 + alias 보너스
        double totalScore = (distanceScore * DISTANCE_WEIGHT) + (headingScore * HEADING_WEIGHT) + aliasBonus;
        SlotIdentity slotIdentity = new SlotIdentity(candidatePlace.getTodo().getId(), place.getId());

        return new ScoredCandidate(
                candidatePlace.getTodo().getId(),
                place.getId(),
                slotIdentity,
                totalScore
        );
    }

    private double bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
        // 현재 위치 -> 목적지 방향의 방위각(0~360도)을 계산한다.
        double phi1 = Math.toRadians(lat1);
        double phi2 = Math.toRadians(lat2);
        double lambda = Math.toRadians(lon2 - lon1);

        double y = Math.sin(lambda) * Math.cos(phi2);
        double x = Math.cos(phi1) * Math.sin(phi2)
                - Math.sin(phi1) * Math.cos(phi2) * Math.cos(lambda);

        double theta = Math.toDegrees(Math.atan2(y, x));
        return (theta + 360.0) % 360.0;
    }

    private double angularDifference(double a, double b) {
        // 두 각도 차이를 최소 각도로 변환 (예: 350도와 10도 차이는 20도)
        double diff = Math.abs(a - b) % 360.0;
        return diff > 180.0 ? 360.0 - diff : diff;
    }

    // 후보 점수 계산 후 내부 처리에 쓰는 경량 DTO.
    private record ScoredCandidate(Long todoId, Long placeId, SlotIdentity identity, double score) {
    }

    // slot_key 대신 사용하는 논리 키:
    // (todoId, placeId) 조합이 같으면 동일 슬롯으로 간주한다.
    private record SlotIdentity(Long todoId, Long placeId) {
    }
}
