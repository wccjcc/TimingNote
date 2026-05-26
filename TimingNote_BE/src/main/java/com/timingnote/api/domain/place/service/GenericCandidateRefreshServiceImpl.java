package com.timingnote.api.domain.place.service;

import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class GenericCandidateRefreshServiceImpl implements GenericCandidateRefreshService {

    private static final int FORWARD_RADIUS_M = 2_500;
    private static final int FORWARD_HALF_ANGLE_DEG = 90;
    private static final int MIN_FORWARD_CANDIDATE_COUNT = 2;

    private final TodoRepository todoRepository;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final PlaceService placeService;
    private final GenericCandidatePersister genericCandidatePersister;

    /**
     * 유의미한 이동 이벤트 수신 시, 사용자의 활성 GENERIC 투두 후보지를 새 좌표 기준으로 갱신한다.
     *
     * <p>흐름:
     * <ol>
     *   <li>활성 GENERIC 투두 목록 조회 (짧은 읽기 트랜잭션, 레포지토리가 자체 관리)</li>
     *   <li>placeLabel 기준으로 그루핑 → 동일 키워드는 Kakao API 1회만 호출</li>
     *   <li>HTTP 호출은 트랜잭션 없이 수행 → 커넥션 점유 없음</li>
     *   <li>DB 갱신은 {@link GenericCandidatePersister#persistOneTodo}에 위임 → 투두별 짧은 쓰기 트랜잭션</li>
     * </ol>
     */
    @Override
    public void refresh(Long userId, BigDecimal latitude, BigDecimal longitude, BigDecimal course) {
        if (latitude == null || longitude == null) {
            log.info("[GenericRefresh] 좌표 없음 → 후보 갱신 스킵: userId={}", userId);
            return;
        }

        // 1. 활성 GENERIC 투두 목록 조회 (레포지토리 기본 readOnly 트랜잭션)
        List<Todo> genericTodos = todoRepository.findActiveGenericTodosByUserId(userId);
        if (genericTodos.isEmpty()) {
            log.info("[GenericRefresh] 활성 GENERIC 투두 없음: userId={}", userId);
            return;
        }

        double lat = latitude.doubleValue();
        double lon = longitude.doubleValue();
        OffsetDateTime now = OffsetDateTime.now();

        // 2. placeLabel 기준 그루핑 → 동일 키워드 Kakao 검색 1회로 줄임
        Map<String, List<Todo>> todosByLabel = genericTodos.stream()
                .collect(Collectors.groupingBy(Todo::getResolvedPlaceLabel));

        for (Map.Entry<String, List<Todo>> entry : todosByLabel.entrySet()) {
            refreshLabelGroup(userId, entry.getKey(), entry.getValue(), now, lat, lon, course);
        }

        log.info("[GenericRefresh] 완료: userId={} genericTodos={} uniqueLabels={}",
                userId, genericTodos.size(), todosByLabel.size());
    }

    private void refreshLabelGroup(
            Long userId,
            String placeLabel,
            List<Todo> todosForLabel,
            OffsetDateTime now,
            double lat,
            double lon,
            BigDecimal course
    ) {
        // 3. HTTP 호출 — 트랜잭션 없음 (커넥션 점유 없음).
        // 등록 흐름(AI)과 동일한 searchAndStoreAll 사용 — 좌표만, radius/sort 미지정, Redis 캐시 경유.
        // 같은 grid·키워드는 카카오 호출 0건으로 흡수된다 (1km grid, 7일 TTL).
        if (!shouldRefreshByForwardCoverage(todosForLabel, now, lat, lon, course)) {
            return;
        }

        Optional<List<Place>> searchedPlaces = searchCandidates(userId, placeLabel, lat, lon);
        if (searchedPlaces.isEmpty()) {
            return;
        }

        List<Place> newPlaces = searchedPlaces.get();
        // Kakao 결과가 비면 기존 후보를 유지 (API 오류를 빈 결과로 신뢰하면 전체 만료 위험)
        if (newPlaces.isEmpty()) {
            log.warn("[GenericRefresh] 재검색 결과 없음 — 기존 후보 유지: placeLabel='{}'", placeLabel);
            return;
        }

        // 4. DB 갱신 — 투두별 짧은 쓰기 트랜잭션으로 위임
        persistCandidates(todosForLabel, newPlaces, lat, lon, now);
    }

    private Optional<List<Place>> searchCandidates(Long userId, String placeLabel, double lat, double lon) {
        try {
            PlaceService.SearchResult searchResult = placeService.searchAndStoreAll(placeLabel, lat, lon);
            List<Place> newPlaces = searchResult.storedPlaces();
            log.info("[포괄장소 후보 재계산 실행] userId={} placeLabel='{}' storedPlaces={}",
                    userId, placeLabel, newPlaces.size());
            return Optional.of(newPlaces);
        } catch (Exception e) {
            log.warn("[GenericRefresh] Kakao 검색 실패 — 스킵: placeLabel='{}' error={}",
                    placeLabel, e.getMessage());
            return Optional.empty();
        }
    }

    private void persistCandidates(
            List<Todo> todosForLabel,
            List<Place> newPlaces,
            double lat,
            double lon,
            OffsetDateTime now
    ) {
        for (Todo todo : todosForLabel) {
            try {
                genericCandidatePersister.persistOneTodo(todo, newPlaces, lat, lon, now);
            } catch (Exception e) {
                log.warn("[GenericRefresh] 투두 후보 갱신 실패 — 스킵: todoId={} error={}",
                        todo.getId(), e.getMessage());
            }
        }
    }

    private boolean shouldRefreshByForwardCoverage(
            List<Todo> todosForLabel,
            OffsetDateTime now,
            double userLat,
            double userLon,
            BigDecimal course
    ) {
        if (course == null) {
            log.info("[FORWARD_GATE] course=null decision=refresh");
            return true;
        }
        double courseDeg = course.doubleValue();
        if (courseDeg < 0.0 || courseDeg >= 360.0) {
            log.info("[FORWARD_GATE] course={} decision=refresh reason=invalid_course", courseDeg);
            return true;
        }

        List<Long> todoIds = todosForLabel.stream()
                .map(Todo::getId)
                .toList();
        if (todoIds.isEmpty()) {
            return true;
        }

        List<TodoCandidatePlace> activeCandidates = todoCandidatePlaceRepository
                .findActiveWithPlaceByTodoIdIn(todoIds, now);

        long forwardCount = activeCandidates.stream()
                .map(TodoCandidatePlace::getPlace)
                .collect(Collectors.toMap(Place::getId, p -> p, (left, right) -> left))
                .values().stream()
                .filter(place -> isInForwardSector(
                        userLat,
                        userLon,
                        place.getLatitude(),
                        place.getLongitude(),
                        courseDeg
                ))
                .count();

        log.info("[FORWARD_GATE] course={} forwardCount={} threshold={} decision={}",
                courseDeg,
                forwardCount,
                MIN_FORWARD_CANDIDATE_COUNT,
                forwardCount < MIN_FORWARD_CANDIDATE_COUNT ? "refresh" : "skip");

        return forwardCount < MIN_FORWARD_CANDIDATE_COUNT;
    }

    private boolean isInForwardSector(
            double userLat,
            double userLon,
            double placeLat,
            double placeLon,
            double courseDeg
    ) {
        double distanceM = GeoUtils.distanceMeters(userLat, userLon, placeLat, placeLon);
        if (distanceM > FORWARD_RADIUS_M) {
            return false;
        }

        double bearing = bearingDegrees(userLat, userLon, placeLat, placeLon);
        double diff = angularDifferenceDegrees(normalizeDegrees(courseDeg), bearing);
        return diff <= FORWARD_HALF_ANGLE_DEG;
    }

    private double bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
        double lat1Rad = Math.toRadians(lat1);
        double lat2Rad = Math.toRadians(lat2);
        double dLonRad = Math.toRadians(lon2 - lon1);

        double y = Math.sin(dLonRad) * Math.cos(lat2Rad);
        double x = Math.cos(lat1Rad) * Math.sin(lat2Rad)
                - Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLonRad);
        return normalizeDegrees(Math.toDegrees(Math.atan2(y, x)));
    }

    private double normalizeDegrees(double degree) {
        double normalized = degree % 360.0;
        return normalized < 0 ? normalized + 360.0 : normalized;
    }

    private double angularDifferenceDegrees(double a, double b) {
        double diff = Math.abs(a - b);
        return diff > 180.0 ? 360.0 - diff : diff;
    }
}
