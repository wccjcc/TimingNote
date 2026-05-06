package com.timingnote.api.domain.todo.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoTimeConditionRequest;
import com.timingnote.api.domain.todo.dto.request.TodoUpdateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListItemResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoInput;
import com.timingnote.api.domain.todo.entity.TodoStructure;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.repository.TodoInputRepository;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoStructureRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import com.timingnote.api.domain.todo.enums.ConditionType;
import com.timingnote.api.domain.todo.enums.InputType;
import com.timingnote.api.domain.todo.enums.StructureStatus;
import com.timingnote.api.domain.todo.enums.TodoStatus;
import com.timingnote.api.domain.todo.enums.TodoType;
import com.timingnote.api.infra.client.ai.AiPlaceType;
import com.timingnote.api.infra.client.ai.AiClient;
import com.timingnote.api.infra.client.ai.dto.AiStructureRequest;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;
import com.timingnote.api.infra.client.ai.dto.AiTimeCondition;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import reactor.core.scheduler.Schedulers;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
public class TodoServiceImpl implements TodoService {

    private final TodoRepository todoRepository;
    private final TodoInputRepository todoInputRepository;
    private final TodoStructureRepository todoStructureRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final PlaceRepository placeRepository;
    private final UserPlaceRepository userPlaceRepository;
    private final AiClient aiClient;
    private final PlaceService placeService;

    // 요일 → 비트마스크 변환 테이블 (MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64)
    private static final Map<String, Integer> DAY_BITMASK = Map.of(
            "MON", 1, "TUE", 2, "WED", 4,
            "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);

    // @Lazy 자기 참조: subscribe() 콜백 및 동일 빈 내 프록시 경유 호출을 위해 사용.
    // 자기 자신을 주입받는 구조상 생성자 주입은 순환 참조로 불가능하므로 필드 주입을 허용한다.
    @Lazy
    @Autowired
    private TodoService self;

    @Override
    @Transactional
    public TodoCreateResponse createTodo(Long userId, TodoCreateRequest request) {
        Todo todo = Todo.builder()
                .userId(userId)
                .content(request.getContent())
                .inputType(request.getInputType())
                .todoType(TodoType.GENERAL.name())  // AI 구조화 전 기본값, saveStructure()에서 갱신
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();

        Todo savedTodo = todoRepository.save(todo);

        // 원본 입력 보관 (inputType별 필드 분기 — VOICE/IMAGE/LINK는 추후 확장)
        todoInputRepository.save(TodoInput.builder()
                .todo(savedTodo)
                .inputType(InputType.valueOf(savedTodo.getInputType()))
                .originalText(savedTodo.getContent())
                .build());

        triggerAiAnalysis(savedTodo.getId(), savedTodo.getInputType(), savedTodo.getContent(),
                request.getLatitude(), request.getLongitude());

        return TodoCreateResponse.builder()
                .todoId(savedTodo.getId())
                .status(savedTodo.getStatus())
                .structureStatus(savedTodo.getStructureStatus())
                .createdAt(savedTodo.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TodoListResponse getTodoList(Long userId, String status, String tab, String placeType, Long cursor, int limit) {
        List<Todo> fetched = todoRepository.findTodoPage(
                userId, status, tab, placeType, cursor, PageRequest.of(0, limit + 1));

        boolean hasNext = fetched.size() > limit;
        List<Todo> page = hasNext ? fetched.subList(0, limit) : fetched;

        List<Long> todoIds = page.stream().map(Todo::getId).toList();
        Map<Long, String> thumbnailMap = fetchThumbnails(todoIds);

        List<TodoListItemResponse> items = page.stream()
                .map(todo -> TodoListItemResponse.from(todo, thumbnailMap.get(todo.getId())))
                .toList();

        return TodoListResponse.builder()
                .items(items)
                .nextCursor(hasNext ? page.get(page.size() - 1).getId() : null)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TodoDetailResponse getTodoDetail(Long userId, Long todoId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        TodoStructure structure = todoStructureRepository.findByTodo_Id(todoId).orElse(null);
        List<TodoTimeCondition> timeConditions =
                todoTimeConditionRepository.findAllByTodo_Id(todoId);
        Place primaryPlace = (todo.getPrimaryPlaceId() != null)
                ? placeRepository.findById(todo.getPrimaryPlaceId()).orElse(null)
                : null;
        List<String> imageUrls = todoInputRepository
                .findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(todoId)
                .stream()
                .flatMap(input -> input.getImageUrl().stream())
                .limit(3)
                .toList();
        String sharedUrl = todoInputRepository
                .findFirstByTodo_IdAndSharedUrlIsNotNull(todoId)
                .map(TodoInput::getSharedUrl)
                .orElse(null);

        return TodoDetailResponse.of(todo, structure, timeConditions, primaryPlace, imageUrls, sharedUrl);
    }

    @Override
    @Transactional
    public TodoDetailResponse updateTodo(Long userId, Long todoId, TodoUpdateRequest request) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        if (StringUtils.hasText(request.getContent())) {
            todo.updateContent(request.getContent());
        }
        if (request.getCategory() != null) {
            todo.updateCategory(request.getCategory().isEmpty() ? null : request.getCategory());
        }
        if (request.getPlaceText() != null) {
            applyPlaceTextUpdate(todo, todoId, request);
        }
        if (request.getTimeConditions() != null) {
            todoTimeConditionRepository.deleteAllByTodo_Id(todoId);
            if (!request.getTimeConditions().isEmpty()) {
                todoTimeConditionRepository.saveAll(
                        request.getTimeConditions().stream()
                                .map(tc -> buildTimeCondition(todo, tc))
                                .toList());
            }
        }
        if (request.getImageUrls() != null) {
            todoInputRepository.deleteAllByTodo_IdAndImageUrlIsNotNull(todoId);
            if (!request.getImageUrls().isEmpty()) {
                todoInputRepository.save(TodoInput.builder()
                        .todo(todo)
                        .inputType(InputType.IMAGE)
                        .imageUrl(request.getImageUrls())
                        .build());
            }
        }
        if (request.getSharedUrl() != null) {
            todoInputRepository.deleteAllByTodo_IdAndSharedUrlIsNotNull(todoId);
            if (!request.getSharedUrl().isEmpty()) {
                todoInputRepository.save(TodoInput.builder()
                        .todo(todo)
                        .inputType(InputType.LINK)
                        .sharedUrl(request.getSharedUrl())
                        .build());
            }
        }

        return self.getTodoDetail(userId, todoId);
    }

    @Override
    @Transactional
    public void updateAlert(Long userId, Long todoId, boolean alertEnabled) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        todo.updateAlertEnabled(alertEnabled);
    }

    @Override
    @Transactional
    public void updateStatus(Long userId, Long todoId, String status) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
        todo.updateStatus(status);
    }

    @Override
    @Transactional
    public TodoDetailResponse setTodoPlace(Long userId, Long todoId, TodoPlaceSetRequest req) {
        // 상호 배타 검증
        boolean hasAlias = req.getUserPlaceId() != null;
        boolean hasExternal = req.getExternalPlace() != null;
        if (hasAlias == hasExternal) {   // 둘 다 있거나 둘 다 없음
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }

        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);

        if (hasAlias) {
            // ── ALIAS: 내 장소 목록에서 선택 ──
            UserPlace userPlace = userPlaceRepository.findByIdAndUser_Id(req.getUserPlaceId(), userId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
            Place place = userPlace.getPlace();

            todo.updateTodoType(TodoType.ALIAS.name());
            todo.updatePrimaryPlaceId(place.getId());
            todo.updateResolvedPlaceLabel(userPlace.getAliasName());
            saveSingleCandidate(todo, place);

            log.info("[Todo/Place] todoId={} → ALIAS placeId={} alias='{}'",
                    todoId, place.getId(), userPlace.getAliasName());

        } else {
            // ── SPECIFIC: Kakao 키워드/주소 검색 또는 지도 마커 핀 ──
            TodoPlaceSetRequest.ExternalPlaceInfo ext = req.getExternalPlace();
            Place place = placeService.saveUserSelectedPlace(PlaceUpsertCommand.of(
                    ext.getKakaoPlaceId(), ext.getPlaceName(),
                    ext.getAddressName(), ext.getRoadAddressName(),
                    ext.getCategoryGroupCode(), ext.getCategoryGroupName(),
                    ext.getPhone(), ext.getPlaceUrl(),
                    ext.getLongitude(), ext.getLatitude()));

            String label = StringUtils.hasText(ext.getRoadAddressName())
                    ? ext.getRoadAddressName() : ext.getPlaceName();

            todo.updateTodoType(TodoType.SPECIFIC.name());
            todo.updatePrimaryPlaceId(place.getId());
            todo.updateResolvedPlaceLabel(label);
            saveSingleCandidate(todo, place);

            log.info("[Todo/Place] todoId={} → SPECIFIC placeId={} label='{}'",
                    todoId, place.getId(), label);
        }

        return self.getTodoDetail(userId, todoId);
    }

    /**
     * SPECIFIC/ALIAS 단건 후보를 todo_candidate_places에 등록한다.
     * distanceM은 0으로 초기화하며, 다음 geofence 재계산 시 PostGIS 실거리로 갱신된다.
     */
    private void saveSingleCandidate(Todo todo, Place place) {
        todoCandidatePlaceRepository.save(TodoCandidatePlace.builder()
                .todo(todo)
                .place(place)
                .distanceM(0)
                .isMonitoringTarget(true)
                .calculatedAt(OffsetDateTime.now(ZoneOffset.UTC))
                .build());
    }

    @Override
    @Transactional
    public void deleteTodos(Long userId, List<Long> ids) {
        if (ids.isEmpty()) return;

        int affected = todoRepository.softDeleteByIdsAndUserId(ids, userId, OffsetDateTime.now(ZoneOffset.UTC));
        if (affected != ids.size()) {
            // 일부 ID가 타인 소유이거나 존재하지 않음 → 전체 롤백
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        // 연결된 후보지 정리 (고아 레코드 방지)
        todoCandidatePlaceRepository.deleteAllByTodoIdIn(ids);
        log.info("[Todo/Delete] userId={} todoIds={} 소프트 삭제 완료", userId, ids);
    }

    @Override
    @Transactional
    public TodoDetailResponse removeTodoPlace(Long userId, Long todoId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        // 장소 핀 해제: 특정 장소 없는 상태(GENERAL)로 복귀
        todo.updateTodoType(TodoType.GENERAL.name());
        todo.updatePrimaryPlaceId(null);
        todo.updateResolvedPlaceLabel(null);
        todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);

        log.info("[Todo/Place] todoId={} 장소 연결 해제", todoId);

        return self.getTodoDetail(userId, todoId);
    }

    /**
     * updateTodo에서 placeText 변경을 처리하는 로직을 분리한 메서드.
     * Cognitive Complexity 감소를 위해 추출.
     * - 빈 문자열("") → 장소 완전 제거 (GENERAL)
     * - non-empty → 포괄 장소(GENERIC)로 전환 후 Kakao 후보 재검색
     */
    private void applyPlaceTextUpdate(Todo todo, Long todoId, TodoUpdateRequest request) {
        if (request.getPlaceText().isEmpty()) {
            // "" → 장소 완전 제거
            todo.updateResolvedPlaceLabel(null);
            todo.updatePrimaryPlaceId(null);
            todo.updateTodoType(TodoType.GENERAL.name());
            todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);
        } else {
            // non-empty → 포괄 장소(GENERIC)로 변경
            todo.updateResolvedPlaceLabel(request.getPlaceText());
            todo.updatePrimaryPlaceId(null);
            todo.updateTodoType(TodoType.GENERIC.name());
            // 기존 후보 제거 후 새 후보 조회·등록
            todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);
            resolveAndSaveGenericCandidates(todo, request.getPlaceText(),
                    request.getLatitude(), request.getLongitude());
        }
    }

    /**
     * GENERIC 후보 장소를 Kakao에서 검색해 todo_candidate_places에 저장한다.
     * 좌표가 없으면 후보 검색 자체를 건너뛴다 (PlaceService 내부에서 빈 리스트 반환).
     */
    private void resolveAndSaveGenericCandidates(Todo todo, String placeText,
                                                  Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            log.info("[Todo/Generic] 좌표 없음 → 후보 검색 스킵: todoId={}", todo.getId());
            return;
        }

        List<Place> candidates = placeService.resolveGenericCandidates(placeText, latitude, longitude);
        if (candidates.isEmpty()) {
            log.info("[Todo/Generic] 후보 없음: todoId={} placeText='{}'", todo.getId(), placeText);
            return;
        }

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        List<TodoCandidatePlace> records = candidates.stream()
                .map(place -> {
                    int distanceM = haversineMeters(latitude, longitude,
                            place.getLatitude(), place.getLongitude());
                    return TodoCandidatePlace.builder()
                            .todo(todo)
                            .place(place)
                            .distanceM(distanceM)
                            .isMonitoringTarget(true)
                            .calculatedAt(now)
                            .build();
                })
                .toList();

        todoCandidatePlaceRepository.saveAll(records);
        log.info("[Todo/Generic] todoId={} → 후보 {}개 저장", todo.getId(), records.size());
    }

    private TodoTimeCondition buildTimeCondition(Todo todo, TodoTimeConditionRequest tc) {
        return TodoTimeCondition.builder()
                .todo(todo)
                .conditionType(ConditionType.valueOf(tc.getConditionType()))
                .startDate(parseDate(tc.getStartDate()))
                .endDate(parseDate(tc.getEndDate()))
                .startTime(parseTime(tc.getStartTime()))
                .endTime(parseTime(tc.getEndTime()))
                .daysOfWeek(toDayBitmask(tc.getDaysOfWeek()))
                .rawExpression(tc.getRawExpression())
                .build();
    }

    private Map<Long, String> fetchThumbnails(List<Long> todoIds) {
        if (todoIds.isEmpty()) return Map.of();
        return todoInputRepository.findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(todoIds)
                .stream()
                .filter(input -> !input.getImageUrl().isEmpty())
                .collect(Collectors.toMap(
                        input -> input.getTodo().getId(),
                        input -> input.getImageUrl().get(0),
                        (a, b) -> a  // 동일 todoId에 IMAGE input이 복수일 경우 첫 번째 유지
                ));
    }

    private void triggerAiAnalysis(Long todoId, String inputType, String content,
                                   Double latitude, Double longitude) {
        AiStructureRequest aiRequest = AiStructureRequest.builder()
                .todoId(todoId)
                .inputType(inputType)
                .originalText(content)
                // TODO: user_places 구현 후 userId 기반으로 별칭 목록 조회하여 주입
                .build();

        aiClient.structureMemo(aiRequest)
                .subscribe(
                        response -> {
                            if (response == null) return;
                            // reactor-http-nio 스레드에서 .block() 금지 → boundedElastic 으로 직접 스케줄링
                            // publishOn 은 WebClientAdapter 내부 operator fusion 으로 무력화될 수 있어
                            // schedule() 은 확실하게 해당 스레드 풀에서 실행 보장
                            Schedulers.boundedElastic().schedule(
                                    () -> self.saveStructure(todoId, response, latitude, longitude)
                            );
                        },
                        e -> {
                            log.error("[AI] 구조화 실패 (todoId={}): {}", todoId, e.getMessage());
                            Schedulers.boundedElastic().schedule(
                                    () -> self.markStructureFailed(todoId)
                            );
                        }
                );
    }

    @Override
    @Transactional
    public void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalStateException("Todo not found: " + todoId));

        // 1. AiPlaceType 변환 (파싱 실패 시 GENERAL로 fallback)
        AiPlaceType placeType = parseEnum(AiPlaceType.class, response.getPlaceType(), AiPlaceType.GENERAL);
        String todoType = placeType.name();

        // 2. TodoStructure 저장
        TodoStructure structure = TodoStructure.builder()
                .todo(todo)
                .todoText(response.getTodoText())
                .category(response.getCategory())
                .placeType(placeType)
                .placeText(response.getPlaceText())
                .timeHintText(response.getTimeHintText())
                .modelUsed(response.getModelUsed() != null ? response.getModelUsed() : "unknown")
                .requestId(response.getRequestId())
                .rawResultJson(response.getRawResultJson())
                .build();

        todoStructureRepository.save(structure);

        // 3. 시간 조건 저장
        List<AiTimeCondition> timeConditions = response.getTimeConditions();
        if (timeConditions != null && !timeConditions.isEmpty()) {
            List<TodoTimeCondition> conditions = timeConditions.stream()
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

        // 4. 장소 연동 (placeType에 따라 분기)
        String placeText = response.getPlaceText();
        if (placeType == AiPlaceType.SPECIFIC && StringUtils.hasText(placeText)) {
            // SPECIFIC: 좌표 없어도 Kakao 전국 accuracy 검색 시도 (지점명 포함이라 정확도 충분)
            // 위치 권한이 없어도 place 저장 → Geofence 등록은 알림 서버가 처리
            // (진입 감지는 OS가 위치 권한 필요 → 알림 서버에서 권한 요청 메시지 발송)
            placeService.resolveSpecificPlace(placeText, latitude, longitude)
                    .ifPresent(place -> todo.updatePrimaryPlaceId(place.getId()));

        } else if (placeType == AiPlaceType.GENERIC
                && StringUtils.hasText(placeText)
                && latitude != null && longitude != null) {
            // GENERIC: 반경 검색이므로 좌표 필수. 위치 권한 없으면 스킵.
            List<Place> candidates = placeService.resolveGenericCandidates(placeText, latitude, longitude);
            if (!candidates.isEmpty()) {
                java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
                List<TodoCandidatePlace> candidatePlaces = candidates.stream()
                        .map(place -> TodoCandidatePlace.builder()
                                .todo(todo)
                                .place(place)
                                .distanceM(haversineMeters(
                                        latitude, longitude,
                                        place.getLatitude(), place.getLongitude()))
                                .isMonitoringTarget(true)
                                .calculatedAt(now)
                                .build())
                        .toList();
                todoCandidatePlaceRepository.saveAll(candidatePlaces);
                log.info("[Place] GENERIC 후보 {} 개 저장 (todoId={})", candidates.size(), todoId);
            }

        } else if (placeType == AiPlaceType.GENERIC && (latitude == null || longitude == null)) {
            log.info("[Place] GENERIC — 위치 권한 없음, 장소 연동 스킵 (todoId={}, placeText={})", todoId, placeText);
        }

        // 5. Todo 상태 갱신
        todo.updateTodoType(todoType);
        if (StringUtils.hasText(response.getCategory())) {
            todo.updateCategory(response.getCategory());
        }
        if (StringUtils.hasText(placeText)) {
            todo.updateResolvedPlaceLabel(placeText);
        }
        todo.updateStructureStatus(StructureStatus.READY.name());

        log.info("[AI] 구조화 저장 완료 (todoId={}, todoType={}, placeType={})", todoId, todoType, placeType);
    }

    @Override
    @Transactional
    public void markStructureFailed(Long todoId) {
        todoRepository.findById(todoId).ifPresent(todo -> {
            todo.updateStructureStatus(StructureStatus.FAILED.name());
            log.warn("[AI] 구조화 FAILED 처리 (todoId={})", todoId);
        });
    }

    private ConditionType parseConditionType(String value) {
        if (!StringUtils.hasText(value)) return null;
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

    private Short toDayBitmask(List<String> days) {
        if (days == null || days.isEmpty()) return null;
        int mask = days.stream()
                .map(d -> DAY_BITMASK.getOrDefault(d.toUpperCase(), 0))
                .reduce(0, (a, b) -> a | b);
        return mask == 0 ? null : (short) mask;
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

    /** Haversine 공식으로 두 좌표 간 거리(m) 계산 */
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
