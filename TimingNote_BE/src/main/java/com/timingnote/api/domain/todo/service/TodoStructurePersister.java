package com.timingnote.api.domain.todo.service;

import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.place.service.PlaceTypeResolver;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoStructure;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.enums.ConditionType;
import com.timingnote.api.domain.todo.enums.StructureStatus;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoStructureRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import com.timingnote.api.domain.todo.search.service.TodoIndexer;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.user.service.UserPlaceAliasMatcher;
import com.timingnote.api.infra.client.ai.AiPlaceType;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;
import com.timingnote.api.infra.client.ai.dto.AiTimeCondition;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * AI 구조화 결과를 DB에 영속화하는 컴포넌트.
 *
 * <p>설계 의도:
 * - {@code TodoServiceImpl}의 {@code saveStructure} / {@code markStructureFailed}가
 *   {@code @Lazy self} 자기 주입을 통해 호출되던 구조를 제거.
 * - {@code triggerAiAnalysis} 콜백({@code Schedulers.boundedElastic})에서
 *   외부 빈으로 호출 → Spring AOP 프록시가 정상 적용 → {@code @Transactional} 동작 보장.
 * - {@code TodoService} 공개 인터페이스에서 내부 구현 메서드 노출 제거.
 *
 * <p>트랜잭션:
 * - 호출 시점에 활성 트랜잭션 없음 (boundedElastic 스레드). REQUIRED → 새 트랜잭션 시작.
 * - {@code save}: TodoStructure / TodoTimeCondition / TodoCandidatePlace / Todo 상태를 단일 트랜잭션으로 원자적 커밋.
 * - {@code markFailed}: Todo.structureStatus = FAILED 단일 업데이트.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TodoStructurePersister {

    private final TodoRepository todoRepository;
    private final TodoStructureRepository todoStructureRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final PlaceService placeService;
    private final PlaceTypeResolver placeTypeResolver;
    private final UserPlaceRepository userPlaceRepository;
    private final UserPlaceAliasMatcher userPlaceAliasMatcher;
    private final TodoIndexer todoIndexer;

    // 요일 → 비트마스크 변환 테이블 (MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64)
    private static final Map<String, Integer> DAY_BITMASK = Map.of(
            "MON", 1, "TUE", 2, "WED", 4,
            "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);

    /**
     * AI 구조화 결과를 DB에 저장하고 Todo 상태를 READY로 갱신한다.
     * 파싱 실패는 partial null 처리(graceful degradation) — 전체 실패 방지.
     *
     * <p>명시 선택 userPlaceId 또는 원문 별칭 매칭으로 ALIAS가 확정되면
     * AI 응답의 placeText는 저장 장소 판단에 사용하지 않는다.
     */
    @Transactional
    public void save(Long todoId, AiStructureResponse response, Double latitude, Double longitude,
                     Long userPlaceId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalStateException("Todo not found: " + todoId));

        // 2026-05-12 설계: placeType은 BE가 검색 결과·user_places 매칭으로 자체 결정.
        // AI 응답의 placeType은 호환성 위해 받지만 사용하지 않음 (Phase D에서 응답 필드 제거 예정).
        saveTimeConditions(todo, response.getTimeConditions());
        PlaceLinkResult placeLink = linkPlace(todo, response.getPlaceText(), latitude, longitude, userPlaceId);
        saveStructureRecord(todo, response, placeLink);
        updateTodoState(todo, placeLink, response);

        log.info("[AI] 구조화 저장 완료 (todoId={}, resolvedPlaceType={}, userPlaceId={})",
                todoId, placeLink.placeType(), userPlaceId);

        // PENDING→READY 전이 시점 — todoType / category / resolvedPlaceLabel / primaryPlaceId 모두 보강된 상태.
        todoIndexer.scheduleAfterCommit(todoId);
    }

    /**
     * AI 처리 실패 시 Todo.structureStatus 를 FAILED 로 마킹한다.
     */
    @Transactional
    public void markFailed(Long todoId) {
        todoRepository.findById(todoId).ifPresent(todo -> {
            todo.updateStructureStatus(StructureStatus.FAILED.name());
            log.warn("[AI] 구조화 FAILED 처리 (todoId={})", todoId);
        });
    }

    // ── 단계별 저장 ─────────────────────────────────────────────────────────

    /**
     * AI 응답을 todo_structures 테이블에 저장.
     *
     * <p>todoText는 AI가 해석/재구성하지 못하도록 응답에서 제거됨(2026-05-13). 사용자 원문(todo.content)을
     * 그대로 복사한다. 입력 필드 자체가 100자 제한이라 별도 truncate 불필요.
     */
    private void saveStructureRecord(Todo todo, AiStructureResponse response, PlaceLinkResult placeLink) {
        todoStructureRepository.save(TodoStructure.builder()
                .todo(todo)
                .todoText(todo.getContent())
                .category(response.getCategory())
                .placeType(placeLink.placeType())
                .placeText(placeLink.resolvedPlaceLabel())
                .timeHintText(response.getTimeHintText())
                .modelUsed(response.getModelUsed() != null ? response.getModelUsed() : "unknown")
                .requestId(response.getRequestId())
                .rawResultJson(response.getRawResultJson())
                .build());
    }

    /** AI 시간 조건 목록을 todo_time_conditions 테이블에 저장 */
    private void saveTimeConditions(Todo todo, List<AiTimeCondition> aiConditions) {
        if (aiConditions == null || aiConditions.isEmpty()) return;

        List<TodoTimeCondition> conditions = aiConditions.stream()
                .map(tc -> TodoTimeCondition.builder()
                        .todo(todo)
                        .conditionType(parseConditionType(tc.getConditionType()))
                        .startDate(parseDate(tc.getStartDate()))
                        .endDate(parseDate(tc.getEndDate()))
                        .startTime(parseTime(tc.getStartTime()))
                        .endTime(parseTime(tc.getEndTime()))
                        .daysOfWeek(toDayBitmask(tc.getDaysOfWeek()))
                        .rawExpression(tc.getRawExpression())
                        .build())
                .toList();
        todoTimeConditionRepository.saveAll(conditions);
    }

    /**
     * placeType을 BE가 자체 결정하면서 장소를 연동한다. 결정된 placeType을 반환.
     *
     * <p>2026-05-12 설계 (문서 4-2 단계):
     * <ol>
     *   <li>{@code userPlaceId} 명시 선택 → ALIAS 확정</li>
     *   <li>원문이 user_places 별칭과 매칭 → ALIAS 확정</li>
     *   <li>{@code placeText} 없음 → GENERAL</li>
     *   <li>{@code placeText}가 user_places 별칭과 매칭 → ALIAS</li>
     *   <li>좌표 없음 → GENERAL (카카오 호출 좌표 필수)</li>
     *   <li>{@code PlaceService.searchAndStoreAll}로 검색 + Place DB 누적</li>
     *   <li>{@code PlaceTypeResolver}로 카테고리 분포·결과 수 기반 분류
     *       (SPECIFIC: 필터 후 1건 → primary, GENERIC: 다수 → 후보 풀)</li>
     * </ol>
     *
     * <p>AI 응답의 placeType은 신뢰하지 않음 — 검증 가능한 데이터(검색 결과·사전·user_places)로 결정.
     *
     * <p>주의: PlaceService 호출에 카카오 HTTP 호출이 포함됨. 트랜잭션 길어짐 — 향후 분리 검토.
     */
    private PlaceLinkResult linkPlace(Todo todo, String placeText, Double latitude, Double longitude,
                                      Long userPlaceId) {
        // 1. 사용자가 FE에서 명시 선택한 ALIAS
        if (userPlaceId != null) {
            return userPlaceRepository.findByIdAndUser_Id(userPlaceId, todo.getUserId())
                    .map(userPlace -> linkAliasPlace(todo, userPlace, "userPlaceId"))
                    .orElseGet(() -> {
                        log.warn("[Place] ALIAS 매칭 실패 — user_places에 없음 (todoId={}, userPlaceId={})",
                                todo.getId(), userPlaceId);
                        return new PlaceLinkResult(AiPlaceType.ALIAS, null);
                    });
        }

        List<UserPlace> userPlaces = userPlaceRepository.findWithPlaceByUserId(todo.getUserId());

        // 2. 원문에 내 장소 별칭이 명시된 경우 AI placeText보다 우선한다.
        Optional<UserPlace> aliasFromOriginalText =
                userPlaceAliasMatcher.findBestMatch(todo.getContent(), userPlaces);
        if (aliasFromOriginalText.isPresent()) {
            return linkAliasPlace(todo, aliasFromOriginalText.get(), "originalText");
        }

        // 3. placeText 없음 → 장소 연동 없음
        if (!StringUtils.hasText(placeText)) {
            log.info("[Place] placeText 없음 → GENERAL (todoId={})", todo.getId());
            return new PlaceLinkResult(AiPlaceType.GENERAL, null);
        }

        // 4. AI가 별칭명을 placeText로 뽑은 경우에도 user_places 기준으로 재검증한다.
        Optional<UserPlace> aliasMatch = userPlaceAliasMatcher.findBestMatch(placeText.trim(), userPlaces);
        if (aliasMatch.isPresent()) {
            return linkAliasPlace(todo, aliasMatch.get(), "placeText");
        }

        boolean hasCoordinates = hasCoordinates(latitude, longitude);

        // 5. 카카오 검색 + Place DB 누적
        // 좌표가 없으면 no-loc 검색으로 장소 타입/특정 장소를 판별하고, 후보 저장은 타입별로 제한한다.
        PlaceService.SearchResult searchResult = placeService.searchAndStoreAll(placeText, latitude, longitude);
        if (searchResult.isEmpty()) {
            log.info("[Place] 카카오 결과 0건 → GENERAL (todoId={}, placeText='{}')", todo.getId(), placeText);
            return new PlaceLinkResult(AiPlaceType.GENERAL, null);
        }

        // 6. PlaceTypeResolver 분류 — 일반명사 사전 + 결과 수
        PlaceTypeResolver.Result resolved = placeTypeResolver.resolve(placeText, searchResult.searchItems());
        if (resolved.placeType() == null) {
            log.info("[Place] resolver MEMO → GENERAL (todoId={}, placeText='{}')",
                    todo.getId(), placeText);
            return new PlaceLinkResult(AiPlaceType.GENERAL, null);
        }

        // 7. 분기 저장 — resolver가 돌려준 items를 storedPlaces에서 lookup
        List<Place> matchedPlaces = matchStoredPlaces(searchResult, resolved.items());
        if (matchedPlaces.isEmpty()) {
            log.warn("[Place] items가 storedPlaces에 없음 — 저장 실패? (todoId={})", todo.getId());
            return new PlaceLinkResult(AiPlaceType.GENERAL, null);
        }

        if (resolved.placeType() == AiPlaceType.SPECIFIC) {
            Place top = matchedPlaces.get(0);
            todo.updatePrimaryPlaceId(top.getId());
            // SPECIFIC 후보 1건 저장 — 수정 흐름(setTodoPlace)과 통일.
            // GeofenceSlotManager가 후보 테이블에서 조회하므로 SPECIFIC도 후보 등록 필수.
            saveCandidatePlaces(todo, List.of(top), latitude, longitude);
            log.info("[Place] SPECIFIC 확정 — placeId={} name='{}' (todoId={})",
                    top.getId(), top.getName(), todo.getId());
            return new PlaceLinkResult(AiPlaceType.SPECIFIC, placeText);
        }

        // GENERIC — 모든 후보를 후보 풀에 저장
        if (!hasCoordinates) {
            log.info("[Place] GENERIC 좌표 없음 → 후보 저장 스킵 (todoId={}, placeText='{}')",
                    todo.getId(), placeText);
            return new PlaceLinkResult(AiPlaceType.GENERIC, placeText);
        }
        saveCandidatePlaces(todo, matchedPlaces, latitude, longitude);
        return new PlaceLinkResult(AiPlaceType.GENERIC, placeText);
    }

    private boolean hasCoordinates(Double latitude, Double longitude) {
        return latitude != null && longitude != null;
    }

    /**
     * resolver가 돌려준 검색 결과 DTO들을 SearchResult의 storedPlaces에서 externalPlaceId 매칭으로 찾는다.
     * 순서 유지 — 카카오 응답 순서(정확도·거리 가중치)를 그대로 따른다.
     */
    private List<Place> matchStoredPlaces(PlaceService.SearchResult sr, List<PlaceSearchItemResponse> items) {
        Map<String, Place> byExternalId = sr.storedPlaces().stream()
                .filter(p -> p.getExternalPlaceId() != null)
                .collect(java.util.stream.Collectors.toMap(
                        Place::getExternalPlaceId, p -> p, (a, b) -> a));
        return items.stream()
                .map(item -> byExternalId.get(item.getId()))
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    private PlaceLinkResult linkAliasPlace(Todo todo, UserPlace userPlace, String source) {
        Place place = userPlace.getPlace();
        todo.updatePrimaryPlaceId(place.getId());
        todo.updateResolvedPlaceLabel(userPlace.getAliasName());
        todoCandidatePlaceRepository.save(TodoCandidatePlace.builder()
                .todo(todo)
                .place(place)
                .distanceM(0)
                .isMonitoringTarget(true)
                .calculatedAt(OffsetDateTime.now())
                .build());
        log.info("[Place] ALIAS 매칭 성공 — placeId={} alias='{}' (todoId={}, src={})",
                place.getId(), userPlace.getAliasName(), todo.getId(), source);
        return new PlaceLinkResult(AiPlaceType.ALIAS, userPlace.getAliasName());
    }

    /** 후보 장소 목록을 todo_candidate_places 에 배치 저장 */
    private void saveCandidatePlaces(Todo todo, List<Place> candidates, Double latitude, Double longitude) {
        boolean hasCoordinates = hasCoordinates(latitude, longitude);
        OffsetDateTime now = OffsetDateTime.now();
        List<TodoCandidatePlace> records = candidates.stream()
                .map(place -> TodoCandidatePlace.builder()
                        .todo(todo)
                        .place(place)
                        .distanceM(hasCoordinates
                                ? (int) Math.round(GeoUtils.distanceMeters(latitude, longitude,
                                        place.getLatitude(), place.getLongitude()))
                                : 0)
                        .isMonitoringTarget(true)
                        .calculatedAt(now)
                        .build())
                .toList();
        todoCandidatePlaceRepository.saveAll(records);
        log.info("[Place] 후보 {}개 저장 (todoId={}, hasCoordinates={})",
                records.size(), todo.getId(), hasCoordinates);
    }

    /** Todo 의 todoType, category, resolvedPlaceLabel, structureStatus 를 갱신 */
    private void updateTodoState(Todo todo, PlaceLinkResult placeLink, AiStructureResponse response) {
        todo.updateTodoType(placeLink.placeType().name());
        if (StringUtils.hasText(response.getCategory())) {
            todo.updateCategory(response.getCategory());
        }
        if (StringUtils.hasText(placeLink.resolvedPlaceLabel())) {
            todo.updateResolvedPlaceLabel(placeLink.resolvedPlaceLabel());
        }
        todo.updateStructureStatus(StructureStatus.READY.name());
    }

    private record PlaceLinkResult(AiPlaceType placeType, String resolvedPlaceLabel) {
    }

    // ── 파싱 유틸 ────────────────────────────────────────────────────────────

    private ConditionType parseConditionType(String value) {
        if (!StringUtils.hasText(value)) return null;
        // AI가 WEEKDAY를 반환하는 경우 WEEK 으로 정규화
        if ("WEEKDAY".equalsIgnoreCase(value)) return ConditionType.WEEK;
        return parseEnum(ConditionType.class, value, null);
    }

    private <E extends Enum<E>> E parseEnum(Class<E> enumClass, String value, E fallback) {
        if (!StringUtils.hasText(value)) return fallback;
        try {
            return Enum.valueOf(enumClass, value);
        } catch (IllegalArgumentException e) {
            log.warn("[AI] 알 수 없는 enum 값 '{}' → {} 로 fallback", value, fallback);
            return fallback;
        }
    }

    private LocalDate parseDate(String value) {
        if (!StringUtils.hasText(value)) return null;
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException e) {
            log.warn("[AI] 날짜 파싱 실패: {}", value);
            return null;
        }
    }

    private LocalTime parseTime(String value) {
        if (!StringUtils.hasText(value)) return null;
        try {
            return LocalTime.parse(value);
        } catch (DateTimeParseException e) {
            log.warn("[AI] 시간 파싱 실패: {}", value);
            return null;
        }
    }

    private Short toDayBitmask(List<String> days) {
        if (days == null || days.isEmpty()) return null;
        int mask = days.stream()
                .map(d -> DAY_BITMASK.getOrDefault(d.toUpperCase(), 0))
                .reduce(0, (a, b) -> a | b);
        return mask == 0 ? null : (short) mask;
    }
}
