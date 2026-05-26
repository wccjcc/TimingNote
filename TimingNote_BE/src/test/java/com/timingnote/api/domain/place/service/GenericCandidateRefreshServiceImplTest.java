package com.timingnote.api.domain.place.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GenericCandidateRefreshServiceImplTest {

    private static final Long USER_ID = 10L;
    private static final BigDecimal LATITUDE = new BigDecimal("37.5665");
    private static final BigDecimal LONGITUDE = new BigDecimal("126.9780");

    @Mock
    private TodoRepository todoRepository;

    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    @Mock
    private PlaceService placeService;

    @Mock
    private GenericCandidatePersister genericCandidatePersister;

    @InjectMocks
    private GenericCandidateRefreshServiceImpl refreshService;

    @Test
    void refresh_skipsAllWork_when_coordinatesAreMissing() {
        refreshService.refresh(USER_ID, null, LONGITUDE, null);

        verifyNoInteractions(todoRepository, todoCandidatePlaceRepository, placeService, genericCandidatePersister);
    }

    @Test
    void refresh_skipsSearch_when_activeGenericTodosAreEmpty() {
        when(todoRepository.findActiveGenericTodosByUserId(USER_ID)).thenReturn(List.of());

        refreshService.refresh(USER_ID, LATITUDE, LONGITUDE, null);

        verify(todoRepository).findActiveGenericTodosByUserId(USER_ID);
        verifyNoInteractions(todoCandidatePlaceRepository, placeService, genericCandidatePersister);
    }

    @Test
    void refresh_searchesOncePerPlaceLabel_andPersistsEachTodo() {
        Todo firstTodo = genericTodo(1L, "약국");
        Todo secondTodo = genericTodo(2L, "약국");
        Place firstPlace = place(100L, "가까운 약국", 37.5665, 126.9780);
        Place secondPlace = place(200L, "다른 약국", 37.5670, 126.9780);
        when(todoRepository.findActiveGenericTodosByUserId(USER_ID))
                .thenReturn(List.of(firstTodo, secondTodo));
        when(placeService.searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue()))
                .thenReturn(new PlaceService.SearchResult(List.of(), List.of(firstPlace, secondPlace)));

        refreshService.refresh(USER_ID, LATITUDE, LONGITUDE, null);

        verify(placeService).searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue());
        verify(genericCandidatePersister).persistOneTodo(eq(firstTodo), eq(List.of(firstPlace, secondPlace)),
                eq(LATITUDE.doubleValue()), eq(LONGITUDE.doubleValue()), any(OffsetDateTime.class));
        verify(genericCandidatePersister).persistOneTodo(eq(secondTodo), eq(List.of(firstPlace, secondPlace)),
                eq(LATITUDE.doubleValue()), eq(LONGITUDE.doubleValue()), any(OffsetDateTime.class));
        verifyNoInteractions(todoCandidatePlaceRepository);
    }

    @Test
    void refresh_keepsExistingCandidates_when_searchReturnsEmptyResult() {
        Todo todo = genericTodo(1L, "약국");
        when(todoRepository.findActiveGenericTodosByUserId(USER_ID)).thenReturn(List.of(todo));
        when(placeService.searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue()))
                .thenReturn(PlaceService.SearchResult.empty());

        refreshService.refresh(USER_ID, LATITUDE, LONGITUDE, null);

        verify(placeService).searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue());
        verify(genericCandidatePersister, never()).persistOneTodo(any(), any(), anyDouble(), anyDouble(), any());
    }

    @Test
    void refresh_skipsKakaoSearch_when_forwardCandidatesAreEnough() {
        Todo todo = genericTodo(1L, "약국");
        Place frontPlace = place(100L, "전방 약국 1", 37.5765, 126.9780);
        Place anotherFrontPlace = place(200L, "전방 약국 2", 37.5770, 126.9780);
        when(todoRepository.findActiveGenericTodosByUserId(USER_ID)).thenReturn(List.of(todo));
        when(todoCandidatePlaceRepository.findActiveWithPlaceByTodoIdIn(eq(List.of(todo.getId())), any(OffsetDateTime.class)))
                .thenReturn(List.of(
                        candidate(todo, frontPlace),
                        candidate(todo, anotherFrontPlace)
                ));

        refreshService.refresh(USER_ID, LATITUDE, LONGITUDE, BigDecimal.ZERO);

        verify(todoCandidatePlaceRepository).findActiveWithPlaceByTodoIdIn(
                eq(List.of(todo.getId())),
                any(OffsetDateTime.class)
        );
        verifyNoInteractions(placeService, genericCandidatePersister);
    }

    @Test
    void refresh_usesKakaoSearch_when_courseIsInvalid() {
        Todo todo = genericTodo(1L, "약국");
        Place place = place(100L, "가까운 약국", 37.5665, 126.9780);
        when(todoRepository.findActiveGenericTodosByUserId(USER_ID)).thenReturn(List.of(todo));
        when(placeService.searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue()))
                .thenReturn(new PlaceService.SearchResult(List.of(), List.of(place)));

        refreshService.refresh(USER_ID, LATITUDE, LONGITUDE, new BigDecimal("360.0"));

        verify(placeService).searchAndStoreAll("약국", LATITUDE.doubleValue(), LONGITUDE.doubleValue());
        verify(genericCandidatePersister).persistOneTodo(eq(todo), eq(List.of(place)),
                eq(LATITUDE.doubleValue()), eq(LONGITUDE.doubleValue()), any(OffsetDateTime.class));
        verifyNoInteractions(todoCandidatePlaceRepository);
    }

    private Todo genericTodo(Long id, String placeLabel) {
        return Todo.builder()
                .id(id)
                .userId(USER_ID)
                .category("HEALTH")
                .inputType("TEXT")
                .todoType("GENERIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content(placeLabel + " 들르기")
                .resolvedPlaceLabel(placeLabel)
                .alertEnabled(true)
                .build();
    }

    private TodoCandidatePlace candidate(Todo todo, Place place) {
        return TodoCandidatePlace.builder()
                .todo(todo)
                .place(place)
                .distanceM(100)
                .isMonitoringTarget(true)
                .calculatedAt(OffsetDateTime.now())
                .build();
    }

    private Place place(Long id, String name, double latitude, double longitude) {
        return Place.builder()
                .id(id)
                .name(name)
                .location(Place.toPoint(longitude, latitude))
                .build();
    }
}
