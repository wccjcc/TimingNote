package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.place.service.PlaceTypeResolver;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoStructure;
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
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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

    private AiStructureResponse response(String placeText, String category) {
        AiStructureResponse response = new AiStructureResponse();
        ReflectionTestUtils.setField(response, "todoId", 1L);
        ReflectionTestUtils.setField(response, "placeText", placeText);
        ReflectionTestUtils.setField(response, "category", category);
        ReflectionTestUtils.setField(response, "timeConditions", List.of());
        ReflectionTestUtils.setField(response, "modelUsed", "test-model");
        return response;
    }
}
