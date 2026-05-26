package com.timingnote.api.domain.todo.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.image.service.ImageFinalizeService;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.notification.service.GeofenceRecalculateOutboxService;
import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.todo.dto.request.TodoAlertUpdateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoStatusUpdateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoTimeConditionRequest;
import com.timingnote.api.domain.todo.dto.request.TodoUpdateRequest;
import com.timingnote.api.domain.todo.dto.response.CandidatePlaceResponse;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoInput;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.enums.ConditionType;
import com.timingnote.api.domain.todo.enums.InputType;
import com.timingnote.api.domain.todo.enums.StructureStatus;
import com.timingnote.api.domain.todo.enums.TodoStatus;
import com.timingnote.api.domain.todo.enums.TodoType;
import com.timingnote.api.domain.todo.repository.TodoInputRepository;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoStructureRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import com.timingnote.api.domain.todo.search.service.TodoIndexer;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.user.service.UserPlaceAliasMatcher;
import com.timingnote.api.infra.client.ai.AiClient;
import com.timingnote.api.infra.client.ai.dto.AiStructureRequest;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;
import reactor.core.publisher.Mono;

@ExtendWith(MockitoExtension.class)
class TodoServiceImplTest {

    private static final Long USER_ID = 10L;
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-05-26T10:00:00+09:00");

    @Mock
    private TodoRepository todoRepository;
    @Mock
    private TodoInputRepository todoInputRepository;
    @Mock
    private TodoStructureRepository todoStructureRepository;
    @Mock
    private TodoTimeConditionRepository todoTimeConditionRepository;
    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    @Mock
    private GeofenceSlotRepository geofenceSlotRepository;
    @Mock
    private PlaceRepository placeRepository;
    @Mock
    private UserPlaceRepository userPlaceRepository;
    @Mock
    private AiClient aiClient;
    @Mock
    private PlaceService placeService;
    @Mock
    private ImageFinalizeService imageFinalizeService;
    @Mock
    private TodoStructurePersister structurePersister;
    @Mock
    private GeofenceRecalculateOutboxService outboxService;
    @Mock
    private TodoIndexer todoIndexer;

    private TodoServiceImpl todoService;

    @BeforeEach
    void setUp() {
        todoService = new TodoServiceImpl(
                todoRepository,
                todoInputRepository,
                todoStructureRepository,
                todoTimeConditionRepository,
                todoCandidatePlaceRepository,
                geofenceSlotRepository,
                placeRepository,
                userPlaceRepository,
                new UserPlaceAliasMatcher(),
                aiClient,
                placeService,
                imageFinalizeService,
                structurePersister,
                outboxService,
                todoIndexer
        );
    }

    @Test
    void createTodo_savesPendingTodoInputRequestsAiAndSchedulesIndexing() {
        TodoCreateRequest request = createRequest(
                "집 근처 약국 들르기",
                InputType.TEXT.name(),
                37.5665,
                126.9780,
                120.0,
                null
        );
        Todo savedTodo = todo(101L, TodoType.GENERAL, null);
        savedTodo.updateContent("집 근처 약국 들르기");
        savedTodo.updateStructureStatus(StructureStatus.PENDING.name());
        when(todoRepository.save(any(Todo.class))).thenReturn(savedTodo);
        when(userPlaceRepository.findWithPlaceByUserId(USER_ID)).thenReturn(List.of());
        when(aiClient.structureMemo(any(AiStructureRequest.class))).thenReturn(Mono.empty());

        TodoCreateResponse response = todoService.createTodo(USER_ID, request);

        ArgumentCaptor<Todo> todoCaptor = ArgumentCaptor.forClass(Todo.class);
        verify(todoRepository).save(todoCaptor.capture());
        Todo todoToSave = todoCaptor.getValue();
        assertThat(todoToSave.getUserId()).isEqualTo(USER_ID);
        assertThat(todoToSave.getContent()).isEqualTo("집 근처 약국 들르기");
        assertThat(todoToSave.getTodoType()).isEqualTo(TodoType.GENERAL.name());
        assertThat(todoToSave.getStatus()).isEqualTo(TodoStatus.ACTIVE.name());
        assertThat(todoToSave.getStructureStatus()).isEqualTo(StructureStatus.PENDING.name());
        assertThat(todoToSave.isAlertEnabled()).isTrue();

        ArgumentCaptor<TodoInput> inputCaptor = ArgumentCaptor.forClass(TodoInput.class);
        verify(todoInputRepository).save(inputCaptor.capture());
        assertThat(inputCaptor.getValue().getTodo()).isSameAs(savedTodo);
        assertThat(inputCaptor.getValue().getInputType()).isEqualTo(InputType.TEXT);
        assertThat(inputCaptor.getValue().getOriginalText()).isEqualTo("집 근처 약국 들르기");

        ArgumentCaptor<AiStructureRequest> aiRequestCaptor = ArgumentCaptor.forClass(AiStructureRequest.class);
        verify(aiClient).structureMemo(aiRequestCaptor.capture());
        assertThat(aiRequestCaptor.getValue().getTodoId()).isEqualTo(101L);
        assertThat(aiRequestCaptor.getValue().getInputType()).isEqualTo(InputType.TEXT.name());
        assertThat(aiRequestCaptor.getValue().getOriginalText()).isEqualTo("집 근처 약국 들르기");
        verify(todoIndexer).scheduleAfterCommit(101L);

        assertThat(response.getTodoId()).isEqualTo(101L);
        assertThat(response.getStatus()).isEqualTo(TodoStatus.ACTIVE.name());
        assertThat(response.getStructureStatus()).isEqualTo(StructureStatus.PENDING.name());
    }

    @Test
    void createTodo_skipsAliasLookup_when_userPlaceIdIsProvided() {
        TodoCreateRequest request = createRequest(
                "집에서 우산 챙기기",
                InputType.TEXT.name(),
                null,
                null,
                null,
                301L
        );
        Todo savedTodo = todo(101L, TodoType.GENERAL, null);
        savedTodo.updateStructureStatus(StructureStatus.PENDING.name());
        when(todoRepository.save(any(Todo.class))).thenReturn(savedTodo);
        when(aiClient.structureMemo(any(AiStructureRequest.class))).thenReturn(Mono.empty());

        todoService.createTodo(USER_ID, request);

        verify(userPlaceRepository, never()).findWithPlaceByUserId(any());
        verify(aiClient).structureMemo(any(AiStructureRequest.class));
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void getTodoList_mapsThumbnailPrimaryPlaceActiveSlotAndNextCursor() {
        Todo firstTodo = todo(101L, TodoType.SPECIFIC, 201L);
        Todo secondTodo = todo(102L, TodoType.GENERIC, null);
        Todo extraTodo = todo(103L, TodoType.GENERIC, null);
        Place primaryPlace = place(201L, "싸피 약국", 37.5665, 126.9780);
        when(todoRepository.findTodoPage(eq(USER_ID), eq("ACTIVE"), eq("HEALTH"), eq("SPECIFIC"),
                eq(null), any(Pageable.class)))
                .thenReturn(List.of(firstTodo, secondTodo, extraTodo));
        when(todoInputRepository.findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(List.of(101L, 102L)))
                .thenReturn(List.of(imageInput(firstTodo, List.of("thumb-1.png", "thumb-2.png"))));
        when(placeRepository.findAllById(List.of(201L))).thenReturn(List.of(primaryPlace));
        when(geofenceSlotRepository.findByUserIdAndActiveTrue(USER_ID))
                .thenReturn(List.of(GeofenceSlot.create(USER_ID, 301L, 102L, NOW, true)));

        TodoListResponse response = todoService.getTodoList(
                USER_ID, "ACTIVE", "HEALTH", "SPECIFIC", null, 2,
                null, null, null, null
        );

        assertThat(response.getNextCursor()).isEqualTo(102L);
        assertThat(response.getItems()).hasSize(2);
        assertThat(response.getItems().get(0).getId()).isEqualTo(101L);
        assertThat(response.getItems().get(0).getThumbnailUrl()).isEqualTo("thumb-1.png");
        assertThat(response.getItems().get(0).getPlaceLatitude()).isEqualTo(37.5665);
        assertThat(response.getItems().get(0).getPlaceLongitude()).isEqualTo(126.9780);
        assertThat(response.getItems().get(0).isActiveSlot()).isFalse();
        assertThat(response.getItems().get(1).getId()).isEqualTo(102L);
        assertThat(response.getItems().get(1).getPlaceLatitude()).isNull();
        assertThat(response.getItems().get(1).isActiveSlot()).isTrue();
    }

    @Test
    void getTodoDetail_sortsActiveCandidatesFirstThenDistance_andExcludesExpiredCandidates() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        Place activePlace = place(201L, "활성 약국", 37.5665, 126.9780);
        Place nearestInactivePlace = place(202L, "가까운 비활성 약국", 37.5666, 126.9780);
        Place expiredPlace = place(203L, "만료 약국", 37.5667, 126.9780);
        TodoCandidatePlace activeCandidate = candidate(1L, todo, activePlace, 300, null);
        TodoCandidatePlace nearestInactiveCandidate = candidate(2L, todo, nearestInactivePlace, 50, null);
        TodoCandidatePlace expiredCandidate = candidate(3L, todo, expiredPlace, 10, NOW);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        when(todoStructureRepository.findByTodo_Id(101L)).thenReturn(Optional.empty());
        when(todoTimeConditionRepository.findAllByTodo_Id(101L)).thenReturn(List.of());
        when(todoInputRepository.findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(101L)).thenReturn(List.of());
        when(todoInputRepository.findFirstByTodo_IdAndSharedUrlIsNotNull(101L)).thenReturn(Optional.empty());
        when(todoCandidatePlaceRepository.findAllWithPlaceByTodoId(101L))
                .thenReturn(List.of(nearestInactiveCandidate, expiredCandidate, activeCandidate));
        when(geofenceSlotRepository.findByUserIdAndActiveTrue(USER_ID))
                .thenReturn(List.of(GeofenceSlot.create(USER_ID, activePlace.getId(), todo.getId(), NOW, true)));

        TodoDetailResponse response = todoService.getTodoDetail(USER_ID, 101L);

        assertThat(response.getCandidates()).hasSize(2);
        CandidatePlaceResponse firstCandidate = response.getCandidates().get(0);
        CandidatePlaceResponse secondCandidate = response.getCandidates().get(1);
        assertThat(firstCandidate.getCandidateId()).isEqualTo(1L);
        assertThat(firstCandidate.isActiveSlot()).isTrue();
        assertThat(firstCandidate.getDistanceM()).isEqualTo(300);
        assertThat(secondCandidate.getCandidateId()).isEqualTo(2L);
        assertThat(secondCandidate.isActiveSlot()).isFalse();
        assertThat(secondCandidate.getDistanceM()).isEqualTo(50);
    }

    @Test
    void getTodoDetail_throwsNotFound_whenTodoDoesNotExist() {
        when(todoRepository.findById(101L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> todoService.getTodoDetail(USER_ID, 101L))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.TODO_NOT_FOUND);

        verifyNoInteractions(
                todoStructureRepository,
                todoTimeConditionRepository,
                todoInputRepository,
                todoCandidatePlaceRepository
        );
    }

    @Test
    void getTodoDetail_throwsForbidden_whenTodoBelongsToOtherUser() {
        Todo todo = Todo.builder()
                .id(101L)
                .userId(999L)
                .inputType(InputType.TEXT.name())
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.READY.name())
                .content("다른 사용자 할 일")
                .alertEnabled(true)
                .build();
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));

        assertThatThrownBy(() -> todoService.getTodoDetail(USER_ID, 101L))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.TODO_FORBIDDEN);

        verifyNoInteractions(
                todoStructureRepository,
                todoTimeConditionRepository,
                todoInputRepository,
                todoCandidatePlaceRepository
        );
    }

    @Test
    void updateStatus_updatesTodo_enqueuesRecalculation_andSchedulesIndexing() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        TodoStatusUpdateRequest request = statusRequest("DONE", 37.5665, 126.9780, 120.0);

        todoService.updateStatus(USER_ID, 101L, request);

        assertThat(todo.getStatus()).isEqualTo(TodoStatus.DONE.name());
        assertThat(todo.getCompletedAt()).isNotNull();
        verify(outboxService).enqueue(
                USER_ID,
                BigDecimal.valueOf(37.5665),
                BigDecimal.valueOf(126.9780),
                BigDecimal.valueOf(120.0)
        );
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void updateAlert_skipsRecalculation_when_coordinatesAreMissing() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        TodoAlertUpdateRequest request = alertRequest(false, null, null, null);

        todoService.updateAlert(USER_ID, 101L, request);

        assertThat(todo.isAlertEnabled()).isFalse();
        verify(outboxService, never()).enqueue(any(), any(), any(), any());
        verify(todoIndexer, never()).scheduleAfterCommit(any());
    }

    @Test
    void deleteTodos_softDeletesOwnedTodos_clearsCandidates_enqueuesRecalculation_andSchedulesIndexing() {
        List<Long> ids = List.of(101L, 102L);
        when(todoRepository.softDeleteByIdsAndUserId(eq(ids), eq(USER_ID), any(OffsetDateTime.class)))
                .thenReturn(2);

        todoService.deleteTodos(USER_ID, ids, 37.5665, 126.9780, 120.0, NOW);

        verify(todoCandidatePlaceRepository).deleteAllByTodoIdIn(ids);
        verify(outboxService).enqueue(
                USER_ID,
                BigDecimal.valueOf(37.5665),
                BigDecimal.valueOf(126.9780),
                BigDecimal.valueOf(120.0)
        );
        verify(todoIndexer).scheduleAfterCommit(101L);
        verify(todoIndexer).scheduleAfterCommit(102L);
    }

    @Test
    void deleteTodos_throwsForbidden_when_notAllTodosBelongToUser() {
        List<Long> ids = List.of(101L, 102L);
        when(todoRepository.softDeleteByIdsAndUserId(eq(ids), eq(USER_ID), any(OffsetDateTime.class)))
                .thenReturn(1);

        assertThatThrownBy(() -> todoService.deleteTodos(USER_ID, ids, null, null, null, null))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.TODO_FORBIDDEN);

        verify(todoCandidatePlaceRepository, never()).deleteAllByTodoIdIn(any());
        verify(outboxService, never()).enqueue(any(), any(), any(), any());
        verify(todoIndexer, never()).scheduleAfterCommit(any());
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void updateTodo_replacesTimeConditions_andConvertsWeekDaysToBitmask() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        stubEmptyDetailDependencies(101L);
        TodoTimeConditionRequest timeCondition = timeConditionRequest(
                "WEEK",
                null,
                null,
                "09:00:00",
                "18:00:00",
                List.of("MON", "WED", "FRI"),
                "월수금 9시부터 18시까지"
        );
        TodoUpdateRequest request = updateRequest(
                null,
                null,
                null,
                null,
                null,
                List.of(timeCondition),
                null,
                null,
                null
        );

        todoService.updateTodo(USER_ID, 101L, request);

        ArgumentCaptor<List> captor = ArgumentCaptor.forClass(List.class);
        verify(todoTimeConditionRepository).deleteAllByTodo_Id(101L);
        verify(todoTimeConditionRepository).saveAll(captor.capture());
        TodoTimeCondition savedCondition = ((List<TodoTimeCondition>) captor.getValue()).get(0);
        assertThat(savedCondition.getConditionType()).isEqualTo(ConditionType.WEEK);
        assertThat(savedCondition.getStartTime().toString()).isEqualTo("09:00");
        assertThat(savedCondition.getEndTime().toString()).isEqualTo("18:00");
        assertThat(savedCondition.getDaysOfWeek()).isEqualTo((short) 21);
        assertThat(savedCondition.getRawExpression()).isEqualTo("월수금 9시부터 18시까지");
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void updateTodo_replacesImagesAndSharedUrl() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        stubEmptyDetailDependencies(101L);
        when(imageFinalizeService.finalizeImageKeys(101L, List.of("temp/a.png", "temp/b.png")))
                .thenReturn(List.of("original/a.png", "original/b.png"));
        TodoUpdateRequest request = updateRequest(
                "수정된 메모",
                "",
                null,
                List.of("temp/a.png", "temp/b.png"),
                "https://example.com/article",
                null,
                null,
                null,
                null
        );

        todoService.updateTodo(USER_ID, 101L, request);

        assertThat(todo.getContent()).isEqualTo("수정된 메모");
        assertThat(todo.getCategory()).isNull();
        verify(todoInputRepository).deleteAllByTodo_IdAndImageUrlIsNotNull(101L);
        verify(todoInputRepository).deleteAllByTodo_IdAndSharedUrlIsNotNull(101L);
        ArgumentCaptor<TodoInput> inputCaptor = ArgumentCaptor.forClass(TodoInput.class);
        verify(todoInputRepository, times(2)).save(inputCaptor.capture());
        List<TodoInput> savedInputs = inputCaptor.getAllValues();
        assertThat(savedInputs)
                .anySatisfy(input -> assertThat(input.getImageUrl())
                        .containsExactly("original/a.png", "original/b.png"))
                .anySatisfy(input -> assertThat(input.getSharedUrl())
                        .isEqualTo("https://example.com/article"));
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    @SuppressWarnings({"unchecked", "rawtypes"})
    void updateTodo_changesPlaceTextToGeneric_savesCandidates_andEnqueuesRecalculation() {
        Todo todo = todo(101L, TodoType.GENERAL, null);
        Place firstPlace = place(201L, "가까운 약국", 37.5665, 126.9780);
        Place secondPlace = place(202L, "다른 약국", 37.5670, 126.9780);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        stubEmptyDetailDependencies(101L);
        when(placeService.searchAndStoreAll("약국", 37.5665, 126.9780))
                .thenReturn(new PlaceService.SearchResult(List.of(), List.of(firstPlace, secondPlace)));
        TodoUpdateRequest request = updateRequest(
                null,
                null,
                "약국",
                null,
                null,
                null,
                37.5665,
                126.9780,
                120.0
        );

        todoService.updateTodo(USER_ID, 101L, request);

        assertThat(todo.getTodoType()).isEqualTo(TodoType.GENERIC.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("약국");
        verify(todoCandidatePlaceRepository).deleteAllByTodo_Id(101L);
        ArgumentCaptor<List> captor = ArgumentCaptor.forClass(List.class);
        verify(todoCandidatePlaceRepository).saveAll(captor.capture());
        assertThat(captor.getValue()).hasSize(2);
        verify(outboxService).enqueue(
                USER_ID,
                BigDecimal.valueOf(37.5665),
                BigDecimal.valueOf(126.9780),
                BigDecimal.valueOf(120.0)
        );
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void updateTodo_clearsPlace_when_placeTextIsEmpty() {
        Todo todo = todo(101L, TodoType.SPECIFIC, 201L);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        stubEmptyDetailDependencies(101L);
        TodoUpdateRequest request = updateRequest(
                null,
                null,
                "",
                null,
                null,
                null,
                null,
                null,
                null
        );

        todoService.updateTodo(USER_ID, 101L, request);

        assertThat(todo.getTodoType()).isEqualTo(TodoType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
        assertThat(todo.getResolvedPlaceLabel()).isNull();
        verify(todoCandidatePlaceRepository).deleteAllByTodo_Id(101L);
        verify(outboxService, never()).enqueue(any(), any(), any(), any());
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void setTodoPlace_withAlias_replacesCandidates_updatesTodo_savesSingleCandidate_andSchedulesSideEffects() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        Place aliasPlace = place(201L, "우리 집", 37.5665, 126.9780);
        UserPlace userPlace = UserPlace.builder()
                .id(301L)
                .aliasName("집")
                .place(aliasPlace)
                .build();
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findByIdAndUser_Id(301L, USER_ID)).thenReturn(Optional.of(userPlace));
        when(placeRepository.findById(201L)).thenReturn(Optional.of(aliasPlace));
        stubEmptyDetailDependencies(101L);
        TodoPlaceSetRequest request = aliasPlaceSetRequest(301L, 37.5665, 126.9780, 120.0);

        TodoDetailResponse response = todoService.setTodoPlace(USER_ID, 101L, request);

        assertThat(todo.getTodoType()).isEqualTo(TodoType.ALIAS.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(201L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("집");
        assertThat(response.getPrimaryPlace().getId()).isEqualTo(201L);
        verify(todoCandidatePlaceRepository).deleteAllByTodo_Id(101L);
        ArgumentCaptor<TodoCandidatePlace> candidateCaptor = ArgumentCaptor.forClass(TodoCandidatePlace.class);
        verify(todoCandidatePlaceRepository).save(candidateCaptor.capture());
        assertThat(candidateCaptor.getValue().getTodo()).isSameAs(todo);
        assertThat(candidateCaptor.getValue().getPlace()).isSameAs(aliasPlace);
        assertThat(candidateCaptor.getValue().getDistanceM()).isZero();
        verify(outboxService).enqueue(
                USER_ID,
                BigDecimal.valueOf(37.5665),
                BigDecimal.valueOf(126.9780),
                BigDecimal.valueOf(120.0)
        );
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void setTodoPlace_withExternalPlace_savesSelectedPlace_updatesTodo_andSchedulesSideEffects() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        Place savedPlace = place(202L, "스타벅스 을지로점", 37.5665, 126.9780);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        when(placeService.saveUserSelectedPlace(any(PlaceUpsertCommand.class))).thenReturn(savedPlace);
        when(placeRepository.findById(202L)).thenReturn(Optional.of(savedPlace));
        stubEmptyDetailDependencies(101L);
        TodoPlaceSetRequest request = externalPlaceSetRequest(37.5665, 126.9780, 120.0);

        TodoDetailResponse response = todoService.setTodoPlace(USER_ID, 101L, request);

        assertThat(todo.getTodoType()).isEqualTo(TodoType.SPECIFIC.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(202L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("서울 중구 을지로 1");
        assertThat(response.getPrimaryPlace().getName()).isEqualTo("스타벅스 을지로점");
        ArgumentCaptor<PlaceUpsertCommand> commandCaptor = ArgumentCaptor.forClass(PlaceUpsertCommand.class);
        verify(placeService).saveUserSelectedPlace(commandCaptor.capture());
        PlaceUpsertCommand command = commandCaptor.getValue();
        assertThat(command.kakaoPlaceId()).isEqualTo("kakao-202");
        assertThat(command.placeName()).isEqualTo("스타벅스 을지로점");
        assertThat(command.longitude()).isEqualTo(126.9780);
        assertThat(command.latitude()).isEqualTo(37.5665);
        verify(todoCandidatePlaceRepository).deleteAllByTodo_Id(101L);
        verify(todoCandidatePlaceRepository).save(any(TodoCandidatePlace.class));
        verify(outboxService).enqueue(
                USER_ID,
                BigDecimal.valueOf(37.5665),
                BigDecimal.valueOf(126.9780),
                BigDecimal.valueOf(120.0)
        );
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void setTodoPlace_throwsValidationError_when_aliasAndExternalAreBothProvided() {
        TodoPlaceSetRequest request = aliasPlaceSetRequest(301L, 37.5665, 126.9780, 120.0);
        ReflectionTestUtils.setField(request, "externalPlace", externalPlaceInfo());

        assertThatThrownBy(() -> todoService.setTodoPlace(USER_ID, 101L, request))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);

        verify(todoRepository, never()).findById(any());
    }

    @Test
    void setTodoPlace_throwsValidationError_when_aliasAndExternalAreBothMissing() {
        TodoPlaceSetRequest request = new TodoPlaceSetRequest();

        assertThatThrownBy(() -> todoService.setTodoPlace(USER_ID, 101L, request))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);

        verify(todoRepository, never()).findById(any());
    }

    @Test
    void setTodoPlace_throwsForbidden_whenTodoBelongsToOtherUser() {
        Todo todo = todoForUser(101L, 999L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        TodoPlaceSetRequest request = aliasPlaceSetRequest(301L, 37.5665, 126.9780, 120.0);

        assertThatThrownBy(() -> todoService.setTodoPlace(USER_ID, 101L, request))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.TODO_FORBIDDEN);

        verifyNoInteractions(
                userPlaceRepository,
                todoCandidatePlaceRepository,
                placeService,
                outboxService,
                todoIndexer
        );
    }

    @Test
    void setTodoPlace_throwsUserPlaceNotFound_withoutClearingExistingCandidates_whenAliasIsInvalid() {
        Todo todo = todo(101L, TodoType.GENERIC, null);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findByIdAndUser_Id(301L, USER_ID)).thenReturn(Optional.empty());
        TodoPlaceSetRequest request = aliasPlaceSetRequest(301L, 37.5665, 126.9780, 120.0);

        assertThatThrownBy(() -> todoService.setTodoPlace(USER_ID, 101L, request))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.USER_PLACE_NOT_FOUND);

        verifyNoInteractions(
                todoCandidatePlaceRepository,
                placeService,
                outboxService,
                todoIndexer
        );
    }

    @Test
    void removeTodoPlace_clearsPlace_deletesCandidates_skipsRecalculationWithoutCoordinates_andSchedulesIndexing() {
        Todo todo = todo(101L, TodoType.SPECIFIC, 201L);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));
        stubEmptyDetailDependencies(101L);

        TodoDetailResponse response = todoService.removeTodoPlace(USER_ID, 101L);

        assertThat(todo.getTodoType()).isEqualTo(TodoType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
        assertThat(todo.getResolvedPlaceLabel()).isNull();
        assertThat(response.getPrimaryPlace()).isNull();
        verify(todoCandidatePlaceRepository).deleteAllByTodo_Id(101L);
        verify(outboxService, never()).enqueue(any(), any(), any(), any());
        verify(todoIndexer).scheduleAfterCommit(101L);
    }

    @Test
    void removeTodoPlace_throwsForbidden_whenTodoBelongsToOtherUser() {
        Todo todo = todoForUser(101L, 999L, TodoType.SPECIFIC, 201L);
        when(todoRepository.findById(101L)).thenReturn(Optional.of(todo));

        assertThatThrownBy(() -> todoService.removeTodoPlace(USER_ID, 101L))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.TODO_FORBIDDEN);

        verifyNoInteractions(
                todoCandidatePlaceRepository,
                outboxService,
                todoIndexer
        );
    }

    private Todo todo(Long id, TodoType type, Long primaryPlaceId) {
        return todoForUser(id, USER_ID, type, primaryPlaceId);
    }

    private Todo todoForUser(Long id, Long userId, TodoType type, Long primaryPlaceId) {
        return Todo.builder()
                .id(id)
                .userId(userId)
                .primaryPlaceId(primaryPlaceId)
                .category("HEALTH")
                .inputType(InputType.TEXT.name())
                .todoType(type.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.READY.name())
                .content("약국 들르기")
                .resolvedPlaceLabel(type == TodoType.GENERIC ? "약국" : "싸피 약국")
                .alertEnabled(true)
                .createdAt(NOW)
                .updatedAt(NOW)
                .build();
    }

    private TodoInput imageInput(Todo todo, List<String> imageUrls) {
        return TodoInput.builder()
                .todo(todo)
                .inputType(InputType.IMAGE)
                .imageUrl(imageUrls)
                .build();
    }

    private TodoCandidatePlace candidate(
            Long id,
            Todo todo,
            Place place,
            int distanceM,
            OffsetDateTime expiresAt
    ) {
        return TodoCandidatePlace.builder()
                .id(id)
                .todo(todo)
                .place(place)
                .distanceM(distanceM)
                .isMonitoringTarget(true)
                .calculatedAt(NOW.minusMinutes(10))
                .expiresAt(expiresAt)
                .build();
    }

    private Place place(Long id, String name, double latitude, double longitude) {
        return Place.builder()
                .id(id)
                .name(name)
                .location(Place.toPoint(longitude, latitude))
                .build();
    }

    private TodoStatusUpdateRequest statusRequest(String status, Double latitude, Double longitude, Double course) {
        TodoStatusUpdateRequest request = new TodoStatusUpdateRequest();
        ReflectionTestUtils.setField(request, "status", status);
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        return request;
    }

    private TodoAlertUpdateRequest alertRequest(Boolean alertEnabled, Double latitude, Double longitude, Double course) {
        TodoAlertUpdateRequest request = new TodoAlertUpdateRequest();
        ReflectionTestUtils.setField(request, "alertEnabled", alertEnabled);
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        return request;
    }

    private TodoCreateRequest createRequest(
            String content,
            String inputType,
            Double latitude,
            Double longitude,
            Double course,
            Long userPlaceId
    ) {
        TodoCreateRequest request = new TodoCreateRequest();
        ReflectionTestUtils.setField(request, "content", content);
        ReflectionTestUtils.setField(request, "inputType", inputType);
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        ReflectionTestUtils.setField(request, "userPlaceId", userPlaceId);
        return request;
    }

    private TodoPlaceSetRequest aliasPlaceSetRequest(
            Long userPlaceId,
            Double latitude,
            Double longitude,
            Double course
    ) {
        TodoPlaceSetRequest request = new TodoPlaceSetRequest();
        ReflectionTestUtils.setField(request, "userPlaceId", userPlaceId);
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        return request;
    }

    private TodoPlaceSetRequest externalPlaceSetRequest(Double latitude, Double longitude, Double course) {
        TodoPlaceSetRequest request = new TodoPlaceSetRequest();
        ReflectionTestUtils.setField(request, "externalPlace", externalPlaceInfo());
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        return request;
    }

    private TodoPlaceSetRequest.ExternalPlaceInfo externalPlaceInfo() {
        TodoPlaceSetRequest.ExternalPlaceInfo externalPlace = new TodoPlaceSetRequest.ExternalPlaceInfo();
        ReflectionTestUtils.setField(externalPlace, "kakaoPlaceId", "kakao-202");
        ReflectionTestUtils.setField(externalPlace, "placeName", "스타벅스 을지로점");
        ReflectionTestUtils.setField(externalPlace, "latitude", 37.5665);
        ReflectionTestUtils.setField(externalPlace, "longitude", 126.9780);
        ReflectionTestUtils.setField(externalPlace, "addressName", "서울 중구 을지로");
        ReflectionTestUtils.setField(externalPlace, "roadAddressName", "서울 중구 을지로 1");
        ReflectionTestUtils.setField(externalPlace, "categoryGroupCode", "CE7");
        ReflectionTestUtils.setField(externalPlace, "categoryGroupName", "카페");
        ReflectionTestUtils.setField(externalPlace, "phone", "02-0000-0000");
        ReflectionTestUtils.setField(externalPlace, "placeUrl", "https://place.map.kakao.com/kakao-202");
        return externalPlace;
    }

    private TodoUpdateRequest updateRequest(
            String content,
            String category,
            String placeText,
            List<String> imageUrls,
            String sharedUrl,
            List<TodoTimeConditionRequest> timeConditions,
            Double latitude,
            Double longitude,
            Double course
    ) {
        TodoUpdateRequest request = new TodoUpdateRequest();
        ReflectionTestUtils.setField(request, "content", content);
        ReflectionTestUtils.setField(request, "category", category);
        ReflectionTestUtils.setField(request, "placeText", placeText);
        ReflectionTestUtils.setField(request, "imageUrls", imageUrls);
        ReflectionTestUtils.setField(request, "sharedUrl", sharedUrl);
        ReflectionTestUtils.setField(request, "timeConditions", timeConditions);
        ReflectionTestUtils.setField(request, "latitude", latitude);
        ReflectionTestUtils.setField(request, "longitude", longitude);
        ReflectionTestUtils.setField(request, "course", course);
        ReflectionTestUtils.setField(request, "occurredAt", NOW);
        return request;
    }

    private TodoTimeConditionRequest timeConditionRequest(
            String conditionType,
            String startDate,
            String endDate,
            String startTime,
            String endTime,
            List<String> daysOfWeek,
            String rawExpression
    ) {
        TodoTimeConditionRequest request = new TodoTimeConditionRequest();
        ReflectionTestUtils.setField(request, "conditionType", conditionType);
        ReflectionTestUtils.setField(request, "startDate", startDate);
        ReflectionTestUtils.setField(request, "endDate", endDate);
        ReflectionTestUtils.setField(request, "startTime", startTime);
        ReflectionTestUtils.setField(request, "endTime", endTime);
        ReflectionTestUtils.setField(request, "daysOfWeek", daysOfWeek);
        ReflectionTestUtils.setField(request, "rawExpression", rawExpression);
        return request;
    }

    private void stubEmptyDetailDependencies(Long todoId) {
        when(todoStructureRepository.findByTodo_Id(todoId)).thenReturn(Optional.empty());
        when(todoTimeConditionRepository.findAllByTodo_Id(todoId)).thenReturn(List.of());
        when(todoInputRepository.findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(todoId)).thenReturn(List.of());
        when(todoInputRepository.findFirstByTodo_IdAndSharedUrlIsNotNull(todoId)).thenReturn(Optional.empty());
        when(todoCandidatePlaceRepository.findAllWithPlaceByTodoId(todoId)).thenReturn(List.of());
    }
}
