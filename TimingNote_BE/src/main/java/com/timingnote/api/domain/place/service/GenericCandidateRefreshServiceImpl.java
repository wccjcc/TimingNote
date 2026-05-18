package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class GenericCandidateRefreshServiceImpl implements GenericCandidateRefreshService {

    private final TodoRepository todoRepository;
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
    public void refresh(Long userId, BigDecimal latitude, BigDecimal longitude) {
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
            String placeLabel = entry.getKey();
            List<Todo> todosForLabel = entry.getValue();

            // 3. HTTP 호출 — 트랜잭션 없음 (커넥션 점유 없음).
            // 등록 흐름(AI)과 동일한 searchAndStoreAll 사용 — 좌표만, radius/sort 미지정, Redis 캐시 경유.
            // 같은 grid·키워드는 카카오 호출 0건으로 흡수된다 (1km grid, 7일 TTL).
            List<Place> newPlaces;
            try {
                PlaceService.SearchResult sr = placeService.searchAndStoreAll(placeLabel, lat, lon);
                newPlaces = sr.storedPlaces();
                log.info("[포괄장소 후보 재계산 실행] userId={} placeLabel='{}' storedPlaces={}",
                        userId, placeLabel, newPlaces.size());
            } catch (Exception e) {
                log.warn("[GenericRefresh] Kakao 검색 실패 — 스킵: placeLabel='{}' error={}",
                        placeLabel, e.getMessage());
                continue;
            }

            // Kakao 결과가 비면 기존 후보를 유지 (API 오류를 빈 결과로 신뢰하면 전체 만료 위험)
            if (newPlaces.isEmpty()) {
                log.warn("[GenericRefresh] 재검색 결과 없음 — 기존 후보 유지: placeLabel='{}'", placeLabel);
                continue;
            }

            // 4. DB 갱신 — 투두별 짧은 쓰기 트랜잭션으로 위임
            for (Todo todo : todosForLabel) {
                try {
                    genericCandidatePersister.persistOneTodo(todo, newPlaces, lat, lon, now);
                } catch (Exception e) {
                    log.warn("[GenericRefresh] 투두 후보 갱신 실패 — 스킵: todoId={} error={}",
                            todo.getId(), e.getMessage());
                }
            }
        }

        log.info("[GenericRefresh] 완료: userId={} genericTodos={} uniqueLabels={}",
                userId, genericTodos.size(), todosByLabel.size());
    }
}
