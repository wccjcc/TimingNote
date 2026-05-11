package com.timingnote.api.domain.todo.service;

import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
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
    private final UserPlaceRepository userPlaceRepository;
    private final TodoIndexer todoIndexer;

    // 요일 → 비트마스크 변환 테이블 (MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64)
    private static final Map<String, Integer> DAY_BITMASK = Map.of(
            "MON", 1, "TUE", 2, "WED", 4,
            "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);

    /**
     * AI 구조화 결과를 DB에 저장하고 Todo 상태를 READY로 갱신한다.
     * 파싱 실패는 partial null 처리(graceful degradation) — 전체 실패 방지.
     *
     * <p>userPlaceId가 있으면 사용자가 명시 선택한 ALIAS이므로 placeType을 ALIAS로 강제 덮어쓰고
     * AI 응답의 placeType/placeText 무시 + ID로 직접 lookup (검색 쿼리 절감, 100% 정확).
     */
    @Transactional
    public void save(Long todoId, AiStructureResponse response, Double latitude, Double longitude,
                     Long userPlaceId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalStateException("Todo not found: " + todoId));

        AiPlaceType placeType;
        String placeText;
        if (userPlaceId != null) {
            placeType = AiPlaceType.ALIAS;
            placeText = null; // linkPlace에서 ID 우선 분기 사용 — placeText 검색 안 함
        } else {
            placeType = parseEnum(AiPlaceType.class, response.getPlaceType(), AiPlaceType.GENERAL);
            placeText = response.getPlaceText();
        }

        saveStructureRecord(todo, response, placeType);
        saveTimeConditions(todo, response.getTimeConditions());
        linkPlace(todo, placeType, placeText, latitude, longitude, userPlaceId);
        updateTodoState(todo, placeType, response);

        log.info("[AI] 구조화 저장 완료 (todoId={}, placeType={}, userPlaceId={})",
                todoId, placeType, userPlaceId);

        // PENDING→READY 전이 시점 — todoType / category / resolvedPlaceLabel / primaryPlaceId 모두 보강된 상태.
        // 이 시점이 가장 풍부한 색인 시점이므로 afterCommit 훅 등록.
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

    /** AI 응답을 todo_structures 테이블에 저장 */
    private void saveStructureRecord(Todo todo, AiStructureResponse response, AiPlaceType placeType) {
        todoStructureRepository.save(TodoStructure.builder()
                .todo(todo)
                .todoText(response.getTodoText())
                .category(response.getCategory())
                .placeType(placeType)
                .placeText(response.getPlaceText())
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
     * placeType에 따라 장소를 연동한다.
     * - SPECIFIC: Kakao 키워드 검색 → primaryPlaceId 설정
     * - GENERIC + 좌표 있음: 반경 검색 → 후보지 N개 저장
     * - GENERIC + 좌표 없음: 위치 권한 없음 → 스킵 (로그만)
     * - ALIAS:
     *   - userPlaceId 있음 (FE 명시 선택) → ID 직접 lookup, 검색 쿼리 X
     *   - userPlaceId 없음 (텍스트 입력) → AI가 인식한 placeText로 user_places 동치 매칭
     * - GENERAL: 장소 연동 없음
     *
     * <p>주의: PlaceService 호출이 포함되므로 트랜잭션 내 HTTP 호출이 발생한다.
     * 현재 규모에서는 허용 가능하며, 향후 HTTP/DB 분리 리팩토링 대상.
     */
    private void linkPlace(Todo todo, AiPlaceType placeType,
                           String placeText, Double latitude, Double longitude,
                           Long userPlaceId) {
        // AI placeType을 그대로 신뢰한다. 과거 AiPlaceTypeValidator로 화이트리스트 키워드 +
        // 한정자 부재 조건으로 SPECIFIC→GENERIC 다운그레이드를 수행했으나, 정확도 책임은
        // AI에 두고 BE는 분기/저장만 담당하도록 단순화한다 (AI 고도화 전제).
        if (placeType == AiPlaceType.SPECIFIC && StringUtils.hasText(placeText)) {
            placeService.resolveSpecificPlace(placeText, latitude, longitude)
                    .ifPresent(place -> todo.updatePrimaryPlaceId(place.getId()));

        } else if (placeType == AiPlaceType.GENERIC
                && StringUtils.hasText(placeText)
                && latitude != null && longitude != null) {
            List<Place> candidates = placeService.resolveGenericCandidates(placeText, latitude, longitude);
            if (!candidates.isEmpty()) {
                saveCandidatePlaces(todo, candidates, latitude, longitude);
            }

        } else if (placeType == AiPlaceType.GENERIC && (latitude == null || longitude == null)) {
            log.info("[Place] GENERIC — 위치 권한 없음, 장소 연동 스킵 (todoId={}, placeText={})",
                    todo.getId(), placeText);

        } else if (placeType == AiPlaceType.ALIAS) {
            linkAliasPlace(todo, placeText, userPlaceId);
        }
    }

    /**
     * ALIAS 장소 연결.
     * - userPlaceId 있음: ID로 직접 lookup (FE 명시 선택, 검색 쿼리 절감)
     * - userPlaceId 없음 + placeText 있음: AI가 인식한 별칭명으로 동치 매칭 (직접 입력)
     * 매칭 실패 시 placeType은 ALIAS로 남지만 primaryPlaceId/candidate가 없어 슬롯 미생성 (로그만).
     */
    private void linkAliasPlace(Todo todo, String aliasNameFromAi, Long userPlaceId) {
        Optional<UserPlace> userPlaceOpt;
        if (userPlaceId != null) {
            userPlaceOpt = userPlaceRepository.findByIdAndUser_Id(userPlaceId, todo.getUserId());
        } else if (StringUtils.hasText(aliasNameFromAi)) {
            userPlaceOpt = userPlaceRepository.findWithPlaceByUserIdAndAliasName(
                    todo.getUserId(), aliasNameFromAi);
        } else {
            log.warn("[Place] ALIAS 매칭 불가 — userPlaceId/placeText 모두 없음 (todoId={})", todo.getId());
            return;
        }

        userPlaceOpt.ifPresentOrElse(
                userPlace -> {
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
                            place.getId(), userPlace.getAliasName(), todo.getId(),
                            userPlaceId != null ? "userPlaceId" : "placeText");
                },
                () -> log.warn("[Place] ALIAS 매칭 실패 — user_places에 없음 (todoId={}, userPlaceId={}, alias='{}')",
                        todo.getId(), userPlaceId, aliasNameFromAi)
        );
    }

    /** GENERIC 후보 장소 목록을 todo_candidate_places 에 배치 저장 */
    private void saveCandidatePlaces(Todo todo, List<Place> candidates, Double latitude, Double longitude) {
        OffsetDateTime now = OffsetDateTime.now();
        List<TodoCandidatePlace> records = candidates.stream()
                .map(place -> TodoCandidatePlace.builder()
                        .todo(todo)
                        .place(place)
                        .distanceM((int) Math.round(
                                GeoUtils.distanceMeters(latitude, longitude,
                                        place.getLatitude(), place.getLongitude())))
                        .isMonitoringTarget(true)
                        .calculatedAt(now)
                        .build())
                .toList();
        todoCandidatePlaceRepository.saveAll(records);
        log.info("[Place] GENERIC 후보 {}개 저장 (todoId={})", records.size(), todo.getId());
    }

    /** Todo 의 todoType, category, resolvedPlaceLabel, structureStatus 를 갱신 */
    private void updateTodoState(Todo todo, AiPlaceType placeType, AiStructureResponse response) {
        todo.updateTodoType(placeType.name());
        if (StringUtils.hasText(response.getCategory())) {
            todo.updateCategory(response.getCategory());
        }
        if (StringUtils.hasText(response.getPlaceText())) {
            todo.updateResolvedPlaceLabel(response.getPlaceText());
        }
        todo.updateStructureStatus(StructureStatus.READY.name());
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
