package com.timingnote.api.domain.todo.service;

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
import com.timingnote.api.domain.todo.enums.TodoStatus;
import com.timingnote.api.domain.todo.enums.TodoType;
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
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TodoStructurePersisterTest {

    @Mock
    private TodoRepository todoRepository;
    @Mock
    private TodoStructureRepository todoStructureRepository;
    @Mock
    private TodoTimeConditionRepository todoTimeConditionRepository;
    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    @Mock
    private PlaceService placeService;
    @Mock
    private PlaceTypeResolver placeTypeResolver;
    @Mock
    private UserPlaceRepository userPlaceRepository;
    @Mock
    private TodoIndexer todoIndexer;

    private final UserPlaceAliasMatcher userPlaceAliasMatcher = new UserPlaceAliasMatcher();

    @Test
    void save_prefersOriginalTextAliasOverAiPlaceText() {
        Todo todo = Todo.builder()
                .id(1L)
                .userId(10L)
                .content("싸피집에서 치킨 먹기")
                .inputType("TEXT")
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();
        Place place = Place.builder()
                .id(100L)
                .name("싸피 기숙사")
                .location(Place.toPoint(127.0, 37.0))
                .build();
        UserPlace userPlace = UserPlace.builder()
                .id(20L)
                .aliasName("싸피집")
                .place(place)
                .build();
        AiStructureResponse response = response("치킨", "DINE");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of(userPlace));

        TodoStructurePersister persister = new TodoStructurePersister(
                todoRepository,
                todoStructureRepository,
                todoTimeConditionRepository,
                todoCandidatePlaceRepository,
                placeService,
                placeTypeResolver,
                userPlaceRepository,
                userPlaceAliasMatcher,
                todoIndexer
        );

        persister.save(1L, response, null, null, null);

        ArgumentCaptor<TodoStructure> structureCaptor = ArgumentCaptor.forClass(TodoStructure.class);
        ArgumentCaptor<TodoCandidatePlace> candidateCaptor = ArgumentCaptor.forClass(TodoCandidatePlace.class);
        verify(todoStructureRepository).save(structureCaptor.capture());
        verify(todoCandidatePlaceRepository).save(candidateCaptor.capture());
        verify(placeService, never()).searchAndStoreAll(any(), any(), any());

        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.ALIAS.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(100L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("싸피집");
        assertThat(todo.getCategory()).isEqualTo("DINE");
        assertThat(todo.getStructureStatus()).isEqualTo(StructureStatus.READY.name());

        TodoStructure savedStructure = structureCaptor.getValue();
        assertThat(savedStructure.getPlaceType()).isEqualTo(AiPlaceType.ALIAS);
        assertThat(savedStructure.getPlaceText()).isEqualTo("싸피집");

        TodoCandidatePlace savedCandidate = candidateCaptor.getValue();
        assertThat(savedCandidate.getPlace()).isSameAs(place);
        assertThat(savedCandidate.isMonitoringTarget()).isTrue();
    }

    @Test
    void save_linksSpecificAndStoresSingleCandidate_whenCoordinatesMissingButNoLocSearchMatches() {
        Todo todo = Todo.builder()
                .id(1L)
                .userId(10L)
                .content("홈플러스 서면점에서 우유 사기")
                .inputType("TEXT")
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();
        Place place = Place.builder()
                .id(100L)
                .externalPlaceId("kakao-100")
                .name("홈플러스 서면점")
                .location(Place.toPoint(129.0600, 35.1577))
                .build();
        PlaceSearchItemResponse item = PlaceSearchItemResponse.builder()
                .id("kakao-100")
                .placeName("홈플러스 서면점")
                .latitude(35.1577)
                .longitude(129.0600)
                .build();
        AiStructureResponse response = response("홈플러스 서면점", "ACQUIRE");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll(eq("홈플러스 서면점"), isNull(), isNull()))
                .thenReturn(new PlaceService.SearchResult(List.of(item), List.of(place)));
        when(placeTypeResolver.resolve(eq("홈플러스 서면점"), eq(List.of(item))))
                .thenReturn(new PlaceTypeResolver.Result(AiPlaceType.SPECIFIC, List.of(item)));

        TodoStructurePersister persister = newPersister();

        persister.save(1L, response, null, null, null);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<TodoCandidatePlace>> candidateCaptor = ArgumentCaptor.forClass(List.class);
        verify(todoCandidatePlaceRepository).saveAll(candidateCaptor.capture());

        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.SPECIFIC.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(100L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("홈플러스 서면점");
        assertThat(candidateCaptor.getValue()).hasSize(1);
        assertThat(candidateCaptor.getValue().get(0).getPlace()).isSameAs(place);
        assertThat(candidateCaptor.getValue().get(0).getDistanceM()).isZero();
    }

    @Test
    void save_keepsGenericLabelButDoesNotStoreCandidates_whenCoordinatesMissing() {
        Todo todo = Todo.builder()
                .id(1L)
                .userId(10L)
                .content("약국 들르기")
                .inputType("TEXT")
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();
        Place place = Place.builder()
                .id(100L)
                .externalPlaceId("kakao-100")
                .name("서면약국")
                .location(Place.toPoint(129.0600, 35.1577))
                .build();
        PlaceSearchItemResponse item = PlaceSearchItemResponse.builder()
                .id("kakao-100")
                .placeName("서면약국")
                .latitude(35.1577)
                .longitude(129.0600)
                .build();
        AiStructureResponse response = response("약국", "HEALTH");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll(eq("약국"), isNull(), isNull()))
                .thenReturn(new PlaceService.SearchResult(List.of(item), List.of(place)));
        when(placeTypeResolver.resolve(eq("약국"), eq(List.of(item))))
                .thenReturn(new PlaceTypeResolver.Result(AiPlaceType.GENERIC, List.of(item)));

        TodoStructurePersister persister = newPersister();

        persister.save(1L, response, null, null, null);

        verify(todoCandidatePlaceRepository, never()).saveAll(any());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERIC.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("약국");
    }

    @Test
    void save_linksAliasFromExplicitUserPlaceId() {
        // given
        Todo todo = todo("집 들르기");
        Place place = place(100L, null, "우리집");
        UserPlace userPlace = userPlace(20L, "집", place);
        AiStructureResponse response = response("약국", "ETC");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findByIdAndUser_Id(20L, 10L)).thenReturn(Optional.of(userPlace));

        // when
        newPersister().save(1L, response, 35.1, 126.9, 20L);

        // then
        ArgumentCaptor<TodoCandidatePlace> candidateCaptor = ArgumentCaptor.forClass(TodoCandidatePlace.class);
        verify(todoCandidatePlaceRepository).save(candidateCaptor.capture());
        verify(placeService, never()).searchAndStoreAll(any(), any(), any());

        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.ALIAS.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(100L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("집");
        assertThat(candidateCaptor.getValue().getDistanceM()).isZero();
        assertThat(candidateCaptor.getValue().getPlace()).isSameAs(place);
    }

    @Test
    void save_keepsAliasTypeWithoutPrimaryPlace_whenExplicitUserPlaceIdDoesNotExist() {
        // given
        Todo todo = todo("집 들르기");
        AiStructureResponse response = response("집", "ETC");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findByIdAndUser_Id(999L, 10L)).thenReturn(Optional.empty());

        // when
        newPersister().save(1L, response, 35.1, 126.9, 999L);

        // then
        ArgumentCaptor<TodoStructure> structureCaptor = ArgumentCaptor.forClass(TodoStructure.class);
        verify(todoStructureRepository).save(structureCaptor.capture());
        verify(placeService, never()).searchAndStoreAll(any(), any(), any());
        verify(todoCandidatePlaceRepository, never()).save(any());
        verify(todoCandidatePlaceRepository, never()).saveAll(any());

        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.ALIAS.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
        assertThat(todo.getResolvedPlaceLabel()).isNull();
        assertThat(structureCaptor.getValue().getPlaceType()).isEqualTo(AiPlaceType.ALIAS);
        assertThat(structureCaptor.getValue().getPlaceText()).isNull();
    }

    @Test
    void save_linksAliasFromAiPlaceTextWhenOriginalTextDoesNotContainAlias() {
        // given
        Todo todo = todo("커피 사기");
        Place place = place(100L, null, "회사 건물");
        UserPlace userPlace = userPlace(20L, "회사", place);
        AiStructureResponse response = response("회사", "SOCIAL");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of(userPlace));

        // when
        newPersister().save(1L, response, null, null, null);

        // then
        ArgumentCaptor<TodoStructure> structureCaptor = ArgumentCaptor.forClass(TodoStructure.class);
        verify(todoStructureRepository).save(structureCaptor.capture());
        verify(placeService, never()).searchAndStoreAll(any(), any(), any());

        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.ALIAS.name());
        assertThat(todo.getPrimaryPlaceId()).isEqualTo(100L);
        assertThat(todo.getResolvedPlaceLabel()).isEqualTo("회사");
        assertThat(structureCaptor.getValue().getPlaceText()).isEqualTo("회사");
    }

    @Test
    void save_marksGeneral_whenPlaceTextIsBlank() {
        // given
        Todo todo = todo("그냥 메모");
        AiStructureResponse response = response(" ", "ETC");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());

        // when
        newPersister().save(1L, response, null, null, null);

        // then
        verify(placeService, never()).searchAndStoreAll(any(), any(), any());
        verify(todoCandidatePlaceRepository, never()).save(any());
        verify(todoCandidatePlaceRepository, never()).saveAll(any());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
    }

    @Test
    void save_marksGeneral_whenSearchResultIsEmpty() {
        // given
        Todo todo = todo("없는 장소 가기");
        AiStructureResponse response = response("없는 장소", "ETC");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll("없는 장소", 35.1, 126.9))
                .thenReturn(PlaceService.SearchResult.empty());

        // when
        newPersister().save(1L, response, 35.1, 126.9, null);

        // then
        verifyNoInteractions(placeTypeResolver);
        verify(todoCandidatePlaceRepository, never()).saveAll(any());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
    }

    @Test
    void save_marksGeneral_whenResolverReturnsMemo() {
        // given
        Todo todo = todo("모호한 장소 가기");
        PlaceSearchItemResponse item = item("kakao-100", "모호한 장소");
        Place place = place(100L, "kakao-100", "모호한 장소");
        AiStructureResponse response = response("모호한 장소", "ETC");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll("모호한 장소", 35.1, 126.9))
                .thenReturn(new PlaceService.SearchResult(List.of(item), List.of(place)));
        when(placeTypeResolver.resolve("모호한 장소", List.of(item)))
                .thenReturn(PlaceTypeResolver.Result.memo());

        // when
        newPersister().save(1L, response, 35.1, 126.9, null);

        // then
        verify(todoCandidatePlaceRepository, never()).saveAll(any());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
    }

    @Test
    void save_marksGeneral_whenResolvedItemsDoNotMatchStoredPlaces() {
        // given
        Todo todo = todo("홈플러스 가기");
        PlaceSearchItemResponse item = item("kakao-100", "홈플러스");
        Place storedOtherPlace = place(200L, "kakao-200", "다른 장소");
        AiStructureResponse response = response("홈플러스", "ACQUIRE");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll("홈플러스", 35.1, 126.9))
                .thenReturn(new PlaceService.SearchResult(List.of(item), List.of(storedOtherPlace)));
        when(placeTypeResolver.resolve("홈플러스", List.of(item)))
                .thenReturn(new PlaceTypeResolver.Result(AiPlaceType.SPECIFIC, List.of(item)));

        // when
        newPersister().save(1L, response, 35.1, 126.9, null);

        // then
        verify(todoCandidatePlaceRepository, never()).saveAll(any());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERAL.name());
        assertThat(todo.getPrimaryPlaceId()).isNull();
    }

    @Test
    void save_storesGenericCandidatesWithDistance_whenCoordinatesExist() {
        // given
        Todo todo = todo("약국 들르기");
        PlaceSearchItemResponse item = item("kakao-100", "서면약국");
        Place place = place(100L, "kakao-100", "서면약국");
        AiStructureResponse response = response("약국", "HEALTH");

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());
        when(placeService.searchAndStoreAll("약국", 35.1577, 129.0600))
                .thenReturn(new PlaceService.SearchResult(List.of(item), List.of(place)));
        when(placeTypeResolver.resolve("약국", List.of(item)))
                .thenReturn(new PlaceTypeResolver.Result(AiPlaceType.GENERIC, List.of(item)));

        // when
        newPersister().save(1L, response, 35.1577, 129.0600, null);

        // then
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<TodoCandidatePlace>> candidateCaptor = ArgumentCaptor.forClass(List.class);
        verify(todoCandidatePlaceRepository).saveAll(candidateCaptor.capture());
        assertThat(todo.getTodoType()).isEqualTo(AiPlaceType.GENERIC.name());
        assertThat(candidateCaptor.getValue()).hasSize(1);
        assertThat(candidateCaptor.getValue().get(0).getPlace()).isSameAs(place);
        assertThat(candidateCaptor.getValue().get(0).getDistanceM()).isZero();
    }

    @Test
    void save_storesTimeConditionsWithParsedValues() {
        // given
        Todo todo = todo("월요일 아침 운동");
        AiTimeCondition timeCondition = timeCondition(
                "WEEKDAY",
                List.of("MON", "SUN"),
                "2026-05-26",
                "2026-06-02",
                "09:00",
                "10:30",
                "월요일 아침"
        );
        AiStructureResponse response = response(null, "HEALTH", List.of(timeCondition));

        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(userPlaceRepository.findWithPlaceByUserId(10L)).thenReturn(List.of());

        // when
        newPersister().save(1L, response, null, null, null);

        // then
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<TodoTimeCondition>> conditionCaptor = ArgumentCaptor.forClass(List.class);
        verify(todoTimeConditionRepository).saveAll(conditionCaptor.capture());

        TodoTimeCondition saved = conditionCaptor.getValue().get(0);
        assertThat(saved.getTodo()).isSameAs(todo);
        assertThat(saved.getConditionType()).isEqualTo(ConditionType.WEEK);
        assertThat(saved.getStartDate()).isEqualTo(LocalDate.of(2026, 5, 26));
        assertThat(saved.getEndDate()).isEqualTo(LocalDate.of(2026, 6, 2));
        assertThat(saved.getStartTime()).isEqualTo(LocalTime.of(9, 0));
        assertThat(saved.getEndTime()).isEqualTo(LocalTime.of(10, 30));
        assertThat(saved.getDaysOfWeek()).isEqualTo((short) 65);
        assertThat(saved.getRawExpression()).isEqualTo("월요일 아침");
    }

    @Test
    void markFailedUpdatesStructureStatus_whenTodoExists() {
        // given
        Todo todo = todo("메모");
        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));

        // when
        newPersister().markFailed(1L);

        // then
        assertThat(todo.getStructureStatus()).isEqualTo(StructureStatus.FAILED.name());
    }

    @Test
    void markFailedDoesNothing_whenTodoDoesNotExist() {
        // given
        when(todoRepository.findById(1L)).thenReturn(Optional.empty());

        // when
        newPersister().markFailed(1L);

        // then
        verifyNoInteractions(todoStructureRepository, todoTimeConditionRepository, todoCandidatePlaceRepository);
    }

    private AiStructureResponse response(String placeText, String category) {
        return response(placeText, category, List.of());
    }

    private AiStructureResponse response(String placeText, String category, List<AiTimeCondition> timeConditions) {
        AiStructureResponse response = new AiStructureResponse();
        ReflectionTestUtils.setField(response, "todoId", 1L);
        ReflectionTestUtils.setField(response, "placeText", placeText);
        ReflectionTestUtils.setField(response, "category", category);
        ReflectionTestUtils.setField(response, "timeConditions", timeConditions);
        ReflectionTestUtils.setField(response, "modelUsed", "test-model");
        return response;
    }

    private AiTimeCondition timeCondition(
            String conditionType,
            List<String> daysOfWeek,
            String startDate,
            String endDate,
            String startTime,
            String endTime,
            String rawExpression
    ) {
        AiTimeCondition condition = new AiTimeCondition();
        ReflectionTestUtils.setField(condition, "conditionType", conditionType);
        ReflectionTestUtils.setField(condition, "daysOfWeek", daysOfWeek);
        ReflectionTestUtils.setField(condition, "startDate", startDate);
        ReflectionTestUtils.setField(condition, "endDate", endDate);
        ReflectionTestUtils.setField(condition, "startTime", startTime);
        ReflectionTestUtils.setField(condition, "endTime", endTime);
        ReflectionTestUtils.setField(condition, "rawExpression", rawExpression);
        return condition;
    }

    private Todo todo(String content) {
        return Todo.builder()
                .id(1L)
                .userId(10L)
                .content(content)
                .inputType("TEXT")
                .todoType(TodoType.GENERAL.name())
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .alertEnabled(true)
                .build();
    }

    private UserPlace userPlace(Long id, String aliasName, Place place) {
        return UserPlace.builder()
                .id(id)
                .aliasName(aliasName)
                .place(place)
                .build();
    }

    private Place place(Long id, String externalPlaceId, String name) {
        return Place.builder()
                .id(id)
                .externalPlaceId(externalPlaceId)
                .name(name)
                .location(Place.toPoint(129.0600, 35.1577))
                .build();
    }

    private PlaceSearchItemResponse item(String id, String placeName) {
        return PlaceSearchItemResponse.builder()
                .id(id)
                .placeName(placeName)
                .latitude(35.1577)
                .longitude(129.0600)
                .build();
    }

    private TodoStructurePersister newPersister() {
        return new TodoStructurePersister(
                todoRepository,
                todoStructureRepository,
                todoTimeConditionRepository,
                todoCandidatePlaceRepository,
                placeService,
                placeTypeResolver,
                userPlaceRepository,
                userPlaceAliasMatcher,
                todoIndexer
        );
    }
}
