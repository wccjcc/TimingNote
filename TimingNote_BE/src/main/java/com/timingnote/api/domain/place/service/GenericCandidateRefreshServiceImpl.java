package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class GenericCandidateRefreshServiceImpl implements GenericCandidateRefreshService {

    private final TodoRepository todoRepository;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final PlaceService placeService;

    @Override
    @Transactional
    public void refresh(Long userId, BigDecimal latitude, BigDecimal longitude) {
        if (latitude == null || longitude == null) {
            log.info("[GenericRefresh] 좌표 없음 → 후보 갱신 스킵: userId={}", userId);
            return;
        }

        List<Todo> genericTodos = todoRepository.findActiveGenericTodosByUserId(userId);
        if (genericTodos.isEmpty()) {
            log.info("[GenericRefresh] 활성 GENERIC 투두 없음: userId={}", userId);
            return;
        }

        double lat = latitude.doubleValue();
        double lon = longitude.doubleValue();
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);

        for (Todo todo : genericTodos) {
            try {
                refreshOneTodo(todo, lat, lon, now);
            } catch (Exception e) {
                log.warn("[GenericRefresh] 투두 후보 갱신 실패 — 스킵: todoId={} error={}",
                        todo.getId(), e.getMessage());
            }
        }

        log.info("[GenericRefresh] 완료: userId={} genericTodos={}", userId, genericTodos.size());
    }

    private void refreshOneTodo(Todo todo, double lat, double lon, OffsetDateTime now) {
        String placeLabel = todo.getResolvedPlaceLabel();

        // 1. 새 위치 기준으로 Kakao 검색
        List<Place> newPlaces = placeService.resolveGenericCandidates(placeLabel, lat, lon);

        // Kakao API 오류나 네트워크 장애로 결과가 비었을 경우 기존 후보를 그대로 유지한다.
        // 빈 결과를 신뢰하면 멀쩡한 후보 전체가 만료될 수 있음
        if (newPlaces.isEmpty()) {
            log.warn("[GenericRefresh] 재검색 결과 없음 — 기존 후보 유지: todoId={} placeLabel='{}'",
                    todo.getId(), placeLabel);
            return;
        }

        Set<Long> newPlaceIds = newPlaces.stream()
                .map(Place::getId)
                .collect(Collectors.toSet());

        // 2. 기존 후보 조회 (만료된 것 포함) — placeId 기준 맵으로 변환
        List<TodoCandidatePlace> existing = todoCandidatePlaceRepository.findAllWithPlaceByTodoId(todo.getId());
        Map<Long, TodoCandidatePlace> existingByPlaceId = existing.stream()
                .collect(Collectors.toMap(tcp -> tcp.getPlace().getId(), Function.identity()));

        List<TodoCandidatePlace> toSave = new ArrayList<>();

        // 3. 새 검색 결과에 있는 장소: 기존이면 재활성화, 없으면 신규 삽입
        for (Place place : newPlaces) {
            int distanceM = haversineMeters(lat, lon, place.getLatitude(), place.getLongitude());
            TodoCandidatePlace candidate = existingByPlaceId.get(place.getId());
            if (candidate != null) {
                // 동일 장소 재발견 — 만료 해제 후 거리 갱신
                candidate.reactivate(distanceM, now);
                toSave.add(candidate);
            } else {
                // 새로 발견된 장소 — 신규 삽입
                toSave.add(TodoCandidatePlace.builder()
                        .todo(todo)
                        .place(place)
                        .distanceM(distanceM)
                        .isMonitoringTarget(true)
                        .calculatedAt(now)
                        .build());
            }
        }

        // 4. 새 검색 결과에 없는 기존 후보 — 만료 처리
        for (TodoCandidatePlace candidate : existing) {
            if (!newPlaceIds.contains(candidate.getPlace().getId())) {
                candidate.expire(now);
                toSave.add(candidate);
            }
        }

        todoCandidatePlaceRepository.saveAll(toSave);
        log.info("[GenericRefresh] todoId={} placeLabel='{}' → 재활성화/신규={}, 만료={}",
                todo.getId(), placeLabel,
                newPlaces.size(),
                existing.size() - (int) existing.stream()
                        .filter(c -> newPlaceIds.contains(c.getPlace().getId())).count());
    }

    private static int haversineMeters(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6_371_000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return (int) Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
    }
}
