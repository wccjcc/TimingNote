package com.timingnote.api.domain.place.service;

import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import java.time.OffsetDateTime;
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

/**
 * GENERIC 후보 장소 갱신 결과를 DB에 영속화하는 컴포넌트.
 *
 * <p>설계 의도:
 * - {@link GenericCandidateRefreshServiceImpl}에서 HTTP(Kakao API) 호출과 DB 쓰기가
 *   동일 트랜잭션 안에 묶이면, HTTP 응답 대기 시간 동안 커넥션이 점유된다.
 * - HTTP 호출은 {@code GenericCandidateRefreshServiceImpl.refresh()}에서 트랜잭션 없이 수행하고,
 *   결과를 이 빈에 위임해 짧고 집중된 쓰기 트랜잭션만 열도록 분리한다.
 * - 외부 빈 호출 → Spring AOP 프록시 경유 → {@code @Transactional} 정상 적용.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GenericCandidatePersister {

    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    /**
     * 단일 투두의 후보 장소 목록을 갱신한다.
     *
     * <p>이미 조회된 {@code newPlaces}를 받아 처리하므로 Kakao API를 재호출하지 않는다.
     * <ul>
     *   <li>새 결과에 있는 기존 후보 → 재활성화(expiresAt = null) + 거리 갱신</li>
     *   <li>새 결과에 있는 신규 장소 → 신규 삽입</li>
     *   <li>새 결과에 없는 기존 후보 → 만료(expiresAt = now) → 슬롯 계산 제외</li>
     * </ul>
     *
     * @param todo      갱신 대상 투두
     * @param newPlaces Kakao 재검색으로 얻은 새 후보 장소 목록 (비어 있으면 호출하지 말 것)
     */
    @Transactional
    public void persistOneTodo(Todo todo, List<Place> newPlaces, double lat, double lon, OffsetDateTime now) {
        Set<Long> newPlaceIds = newPlaces.stream()
                .map(Place::getId)
                .collect(Collectors.toSet());

        // 기존 후보 조회 (만료된 것 포함) — placeId 기준 맵으로 변환
        List<TodoCandidatePlace> existing = todoCandidatePlaceRepository.findAllWithPlaceByTodoId(todo.getId());
        Map<Long, TodoCandidatePlace> existingByPlaceId = existing.stream()
                .collect(Collectors.toMap(tcp -> tcp.getPlace().getId(), Function.identity()));

        List<TodoCandidatePlace> toSave = new ArrayList<>();

        // 새 검색 결과에 있는 장소: 기존이면 재활성화, 없으면 신규 삽입
        for (Place place : newPlaces) {
            int distanceM = (int) Math.round(
                    GeoUtils.distanceMeters(lat, lon, place.getLatitude(), place.getLongitude()));
            TodoCandidatePlace candidate = existingByPlaceId.get(place.getId());
            if (candidate != null) {
                candidate.reactivate(distanceM, now);
                toSave.add(candidate);
            } else {
                toSave.add(TodoCandidatePlace.builder()
                        .todo(todo)
                        .place(place)
                        .distanceM(distanceM)
                        .isMonitoringTarget(true)
                        .calculatedAt(now)
                        .build());
            }
        }

        // 새 검색 결과에 없는 기존 후보 → 만료 처리
        for (TodoCandidatePlace candidate : existing) {
            if (!newPlaceIds.contains(candidate.getPlace().getId())) {
                candidate.expire(now);
                toSave.add(candidate);
            }
        }

        todoCandidatePlaceRepository.saveAll(toSave);

        long expiredCount = existing.stream()
                .filter(c -> !newPlaceIds.contains(c.getPlace().getId()))
                .count();
        log.info("[GenericRefresh] todoId={} placeLabel='{}' → 재활성화/신규={}, 만료={}",
                todo.getId(), todo.getResolvedPlaceLabel(), newPlaces.size(), expiredCount);
    }
}
