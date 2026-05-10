package com.timingnote.api.domain.todo.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.notification.service.GeofenceRecalculateOutboxService;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.image.service.ImageFinalizeService;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.todo.dto.request.TodoAlertUpdateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoStatusUpdateRequest;
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
import com.timingnote.api.domain.todo.search.service.TodoIndexer;
import com.timingnote.api.infra.client.ai.AiClient;
import com.timingnote.api.infra.client.ai.dto.AiStructureRequest;
import com.timingnote.api.infra.client.ai.dto.UserPlaceAlias;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import reactor.core.scheduler.Schedulers;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

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
    private final ImageFinalizeService imageFinalizeService;
    // AI 비동기 콜백의 트랜잭션 경계 위임용 외부 빈 (AOP 프록시 경유 목적)
    private final TodoStructurePersister structurePersister;
    // todo CRUD 트랜잭션에 outbox INSERT가 합류 → 롤백 원자성 확보
    private final GeofenceRecalculateOutboxService outboxService;
    // ES 검색 인덱스 동기화 — afterCommit 훅 등록 (Todo 내부 이벤트 패턴)
    private final TodoIndexer todoIndexer;

    // 요일 → 비트마스크 변환 테이블 (updateTodo의 사용자 시간 조건 파싱 전용)
    // AI 파싱용은 TodoStructurePersister 에서 별도 관리
    private static final Map<String, Integer> DAY_BITMASK = Map.of(
            "MON", 1, "TUE", 2, "WED", 4,
            "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);

    // ── 생성 ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public TodoCreateResponse createTodo(Long userId, TodoCreateRequest request) {
        Todo todo = Todo.builder()
                .userId(userId)
                .content(request.getContent())
                .inputType(request.getInputType())
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();

        Todo savedTodo = todoRepository.save(todo);

        todoInputRepository.save(TodoInput.builder()
                .todo(savedTodo)
                .inputType(InputType.valueOf(savedTodo.getInputType()))
                .originalText(savedTodo.getContent())
                .build());

        // Geofence 재계산은 AI 분석 완료(후보 장소 저장) 후 triggerAiAnalysis 콜백에서 enqueue.
        // userPlaceId가 있으면 ALIAS 매칭 시 검색 쿼리 없이 ID로 직접 연결됨.
        triggerAiAnalysis(userId, savedTodo.getId(), savedTodo.getInputType(), savedTodo.getContent(),
                request.getLatitude(), request.getLongitude(),
                request.getCourse(), request.getOccurredAt(),
                request.getUserPlaceId());

        // PENDING 상태 그대로 색인(content 검색 가능). AI 콜백에서 placeLabel 등 보강 후 재색인.
        todoIndexer.scheduleAfterCommit(savedTodo.getId());

        return TodoCreateResponse.builder()
                .todoId(savedTodo.getId())
                .status(savedTodo.getStatus())
                .structureStatus(savedTodo.getStructureStatus())
                .createdAt(savedTodo.getCreatedAt())
                .build();
    }

    // ── 조회 ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public TodoListResponse getTodoList(Long userId, String status, String tab, String placeType,
                                        Long cursor, int limit,
                                        Double latitude, Double longitude, Double course, OffsetDateTime occurredAt) {
        // 좌표 4종은 향후 거리 기반 정렬/필터에 활용 예정 — 현재는 receiving만
        List<Todo> fetched = todoRepository.findTodoPage(
                userId, status, tab, placeType, cursor, PageRequest.of(0, limit + 1));

        boolean hasNext = fetched.size() > limit;
        List<Todo> page = hasNext ? fetched.subList(0, limit) : fetched;

        List<Long> todoIds = page.stream().map(Todo::getId).toList();
        Map<Long, String> thumbnailMap = fetchThumbnails(todoIds);

        List<TodoListItemResponse> items = page.stream()
                .map(t -> TodoListItemResponse.from(t, thumbnailMap.get(t.getId())))
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
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }
        return assembleTodoDetail(todo);
    }

    // ── 수정 ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public TodoDetailResponse updateTodo(Long userId, Long todoId, TodoUpdateRequest request) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }

        if (StringUtils.hasText(request.getContent())) {
            todo.updateContent(request.getContent());
        }
        if (request.getCategory() != null) {
            todo.updateCategory(request.getCategory().isEmpty() ? null : request.getCategory());
        }
        if (request.getPlaceText() != null) {
            applyPlaceTextUpdate(todo, todoId, request);
            // 장소 텍스트 변경 → 슬롯 재계산 outbox enqueue (Kakao 재검색은 방금 완료)
            enqueueSlotRecalculate(userId, request.getLatitude(), request.getLongitude(),
                    request.getCourse(), request.getOccurredAt());
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
                // 수정 완료 시점에 temp 이미지 키를 최종 original 키로 확정
                List<String> finalizedImageKeys = imageFinalizeService.finalizeImageKeys(todoId, request.getImageUrls());
                todoInputRepository.save(TodoInput.builder()
                        .todo(todo)
                        .inputType(InputType.IMAGE)
                        .imageUrl(finalizedImageKeys)
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

        todoIndexer.scheduleAfterCommit(todoId);

        // self 프록시 없이 직접 조합 — 이미 로드된 todo 재사용으로 이중 SELECT 제거
        return assembleTodoDetail(todo);
    }

    @Override
    @Transactional
    public void updateAlert(Long userId, Long todoId, TodoAlertUpdateRequest request) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }
        todo.updateAlertEnabled(request.getAlertEnabled());
        // 알림 on/off → recalculateSlots의 hard rule(alertEnabled) 필터 변경되므로 슬롯 재계산
        enqueueSlotRecalculate(userId, request.getLatitude(), request.getLongitude(),
                request.getCourse(), request.getOccurredAt());
    }

    @Override
    @Transactional
    public void updateStatus(Long userId, Long todoId, TodoStatusUpdateRequest request) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }
        todo.updateStatus(request.getStatus());
        // DONE↔ACTIVE 전환 시 monitoring 쿼리(status='ACTIVE') 필터가 바뀌므로 슬롯 재계산
        enqueueSlotRecalculate(userId, request.getLatitude(), request.getLongitude(),
                request.getCourse(), request.getOccurredAt());
        // status / completedAt 변경 → 검색 색인도 갱신
        todoIndexer.scheduleAfterCommit(todoId);
    }

    // ── 장소 지정/해제 ────────────────────────────────────────────────────────

    @Override
    @Transactional
    public TodoDetailResponse setTodoPlace(Long userId, Long todoId, TodoPlaceSetRequest req) {
        boolean hasAlias = req.getUserPlaceId() != null;
        boolean hasExternal = req.getExternalPlace() != null;
        if (hasAlias == hasExternal) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }

        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }

        todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);

        if (hasAlias) {
            UserPlace userPlace = userPlaceRepository.findByIdAndUser_Id(req.getUserPlaceId(), userId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.USER_PLACE_NOT_FOUND));
            Place place = userPlace.getPlace();

            todo.updateTodoType(TodoType.ALIAS.name());
            todo.updatePrimaryPlaceId(place.getId());
            todo.updateResolvedPlaceLabel(userPlace.getAliasName());
            saveSingleCandidate(todo, place);

            log.info("[Todo/Place] todoId={} → ALIAS placeId={} alias='{}'",
                    todoId, place.getId(), userPlace.getAliasName());
        } else {
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

        // 장소 설정 → 슬롯 재계산 outbox enqueue (후보는 이미 저장됨)
        enqueueSlotRecalculate(userId, req.getLatitude(), req.getLongitude(),
                req.getCourse(), req.getOccurredAt());

        // resolvedPlaceLabel / primaryPlaceId 변경 → 검색 색인 갱신 (placeName 새로 조인)
        todoIndexer.scheduleAfterCommit(todoId);

        // 이미 로드된 todo 재사용 — primaryPlaceId 업데이트 후 L1 캐시에서 place 조회
        return assembleTodoDetail(todo);
    }

    @Override
    @Transactional
    public TodoDetailResponse removeTodoPlace(Long userId, Long todoId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.TODO_NOT_FOUND));
        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }

        todo.updateTodoType(TodoType.GENERAL.name());
        todo.updatePrimaryPlaceId(null);
        todo.updateResolvedPlaceLabel(null);
        todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);

        // 장소 제거 → 좌표 없으면 enqueue 스킵 (다음 액션에서 자연 복구).
        // 좌표 없이 호출하므로 메모 모드/권한 거부 사용자 보호 가드에 의해 스킵됨.
        enqueueSlotRecalculate(userId, null, null, null, null);

        // resolvedPlaceLabel / primaryPlaceId 모두 null로 변경 → 검색 색인 갱신
        todoIndexer.scheduleAfterCommit(todoId);

        log.info("[Todo/Place] todoId={} 장소 연결 해제", todoId);
        return assembleTodoDetail(todo);
    }

    // ── 삭제 ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public void deleteTodos(Long userId, List<Long> ids,
                            Double latitude, Double longitude, Double course, OffsetDateTime occurredAt) {
        if (ids.isEmpty()) return;

        int affected = todoRepository.softDeleteByIdsAndUserId(ids, userId, OffsetDateTime.now());
        if (affected != ids.size()) {
            throw new BusinessException(ErrorCode.TODO_FORBIDDEN);
        }

        todoCandidatePlaceRepository.deleteAllByTodoIdIn(ids);
        log.info("[Todo/Delete] userId={} todoIds={} 소프트 삭제 완료", userId, ids);

        // 삭제된 todo 슬롯 비활성화 — candidates 제거 후 재계산으로 geofence_slots 정리
        enqueueSlotRecalculate(userId, latitude, longitude, course, occurredAt);

        // status=DELETED로 색인 갱신 → 검색 쿼리의 must_not 필터로 자연 제외
        ids.forEach(todoIndexer::scheduleAfterCommit);
    }

    // ── 상세 응답 조립 ────────────────────────────────────────────────────────

    /**
     * 이미 로드된 Todo 엔티티를 기반으로 상세 응답을 조립한다.
     *
     * <p>호출 맥락:
     * <ul>
     *   <li>{@link #getTodoDetail}: 소유권 검증 후 호출 (readOnly 트랜잭션)</li>
     *   <li>{@link #updateTodo}, {@link #setTodoPlace}, {@link #removeTodoPlace}:
     *       이미 로드·수정된 todo 재사용 → todoRepository.findById 이중 호출 제거</li>
     * </ul>
     *
     * <p>primaryPlaceId가 있을 때 placeRepository.findById 는 동일 트랜잭션 L1 캐시에서 처리된다.
     */
    private TodoDetailResponse assembleTodoDetail(Todo todo) {
        Long todoId = todo.getId();
        TodoStructure structure = todoStructureRepository.findByTodo_Id(todoId).orElse(null);
        List<TodoTimeCondition> timeConditions = todoTimeConditionRepository.findAllByTodo_Id(todoId);
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

    // ── AI 분석 트리거 ────────────────────────────────────────────────────────

    /**
     * AI 구조화 요청을 비동기로 발사한다.
     *
     * <p>subscribe 콜백은 reactor-http-nio 스레드에서 실행되므로
     * JPA 블로킹 작업을 boundedElastic 으로 위임한다.
     * {@code structurePersister}는 외부 빈 참조 → Spring AOP 프록시 경유 →
     * {@code @Transactional} 새 트랜잭션 정상 시작.
     */
    private void triggerAiAnalysis(Long userId, Long todoId, String inputType, String content,
                                   Double latitude, Double longitude,
                                   Double course, OffsetDateTime occurredAt,
                                   Long userPlaceId) {
        List<UserPlaceAlias> aliases = userPlaceRepository.findWithPlaceByUserId(userId).stream()
                .map(up -> UserPlaceAlias.builder().alias(up.getAliasName()).build())
                .toList();

        AiStructureRequest aiRequest = AiStructureRequest.builder()
                .todoId(todoId)
                .inputType(inputType)
                .originalText(content)
                .userPlaceAliases(aliases)
                .build();

        aiClient.structureMemo(aiRequest)
                .subscribe(
                        response -> {
                            if (response == null) return;
                            // boundedElastic: 트랜잭션 없는 스레드에서 save() 실행 → 커밋 완료 후 outbox enqueue
                            // enqueue는 자체 @Transactional로 새 트랜잭션 시작 → 정상 동작
                            Schedulers.boundedElastic().schedule(() -> {
                                structurePersister.save(todoId, response, latitude, longitude, userPlaceId);
                                enqueueSlotRecalculate(userId, latitude, longitude, course, occurredAt);
                            });
                        },
                        e -> {
                            log.error("[AI] 구조화 실패 todoId={}", todoId, e);
                            Schedulers.boundedElastic().schedule(
                                    () -> structurePersister.markFailed(todoId)
                            );
                        }
                );
    }

    // ── 장소 헬퍼 ────────────────────────────────────────────────────────────

    /**
     * placeText 변경 처리: "" = 장소 제거(GENERAL), non-empty = GENERIC으로 전환.
     */
    private void applyPlaceTextUpdate(Todo todo, Long todoId, TodoUpdateRequest request) {
        if (request.getPlaceText().isEmpty()) {
            todo.updateResolvedPlaceLabel(null);
            todo.updatePrimaryPlaceId(null);
            todo.updateTodoType(TodoType.GENERAL.name());
            todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);
        } else {
            todo.updateResolvedPlaceLabel(request.getPlaceText());
            todo.updatePrimaryPlaceId(null);
            todo.updateTodoType(TodoType.GENERIC.name());
            todoCandidatePlaceRepository.deleteAllByTodo_Id(todoId);
            resolveAndSaveGenericCandidates(todo, request.getPlaceText(),
                    request.getLatitude(), request.getLongitude());
        }
    }

    /**
     * GENERIC 후보 장소를 Kakao에서 검색해 todo_candidate_places에 저장.
     * 좌표 없으면 스킵.
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
        log.info("[Todo/Generic] todoId={} → 후보 {}개 저장", todo.getId(), records.size());
    }

    /**
     * SPECIFIC/ALIAS 단건 후보를 todo_candidate_places에 등록.
     * distanceM = 0 초기화, 다음 geofence 재계산 시 PostGIS 실거리로 갱신됨.
     */
    private void saveSingleCandidate(Todo todo, Place place) {
        todoCandidatePlaceRepository.save(TodoCandidatePlace.builder()
                .todo(todo)
                .place(place)
                .distanceM(0)
                .isMonitoringTarget(true)
                .calculatedAt(OffsetDateTime.now())
                .build());
    }

    // ── 목록 조회 헬퍼 ────────────────────────────────────────────────────────

    private Map<Long, String> fetchThumbnails(List<Long> todoIds) {
        if (todoIds.isEmpty()) return Map.of();
        return todoInputRepository.findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(todoIds)
                .stream()
                .filter(input -> !input.getImageUrl().isEmpty())
                .collect(Collectors.toMap(
                        input -> input.getTodo().getId(),
                        input -> input.getImageUrl().get(0),
                        (a, b) -> a   // 동일 todoId에 IMAGE input 복수 시 첫 번째 유지
                ));
    }

    // ── Geofence 재계산 ───────────────────────────────────────────────────────

    /**
     * Todo CRUD 트랜잭션 안에서 호출하면 같은 트랜잭션에 outbox row INSERT가 합류(REQUIRED)
     * → todo 변경과 outbox row가 원자적으로 커밋/롤백된다.
     *
     * <p>좌표 없으면 슬롯 재계산 의미 없음 — 메모 모드 사용자(위치 권한 거부) 보호.
     * BE의 {@code recalculateSlots}는 좌표 필수 contract이므로 호출 자체를 스킵한다.
     * occurredAt은 outbox 시그니처 미지원으로 receiving만 (정우주 영역 확장 시 전달 예정).
     */
    private void enqueueSlotRecalculate(Long userId, Double lat, Double lon, Double course, OffsetDateTime occurredAt) {
        if (lat == null || lon == null) {
            log.debug("[Todo] 좌표 없음 → 슬롯 재계산 enqueue 스킵 userId={}", userId);
            return;
        }
        outboxService.enqueue(
                userId,
                BigDecimal.valueOf(lat),
                BigDecimal.valueOf(lon),
                course != null ? BigDecimal.valueOf(course) : null
        );
    }

    // ── 시간 조건 빌더 (사용자 요청 DTO 전용) ────────────────────────────────

    /**
     * 사용자가 직접 입력한 시간 조건({@link TodoTimeConditionRequest})을 엔티티로 변환.
     * AI 응답 DTO({@link com.timingnote.api.infra.client.ai.dto.AiTimeCondition}) 변환은
     * {@link TodoStructurePersister}에서 처리.
     */
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
            // 사용자 직접 입력 경로에서만 호출됨 (buildTimeCondition).
            // AI 응답 파싱 경로의 silent fallback은 TodoStructurePersister 쪽.
            throw new BusinessException(ErrorCode.TODO_INVALID_TIME_FORMAT);
        }
    }

    private LocalTime parseTime(String value) {
        if (!StringUtils.hasText(value)) return null;
        try {
            return LocalTime.parse(value);
        } catch (DateTimeParseException e) {
            throw new BusinessException(ErrorCode.TODO_INVALID_TIME_FORMAT);
        }
    }
}
