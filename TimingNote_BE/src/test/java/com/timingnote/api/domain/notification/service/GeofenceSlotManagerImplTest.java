package com.timingnote.api.domain.notification.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.notification.dto.request.GeofenceSlotRecalculateEvent;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.repository.projection.TodoCandidateDistanceProjection;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GeofenceSlotManagerImplTest {

    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    @Mock
    private GeofenceSlotRepository geofenceSlotRepository;

    @Mock
    private UserPlaceRepository userPlaceRepository;

    @Mock
    private GeofenceSlotSseService geofenceSlotSseService;

    @InjectMocks
    private GeofenceSlotManagerImpl geofenceSlotManager;

    @Test
    void recalculateSlots_excludesCandidateWithoutRealtimeDistance_whenCurrentLocationExists() {
        // given: 위치 기반 재계산 이벤트
        Long userId = 1L;
        GeofenceSlotRecalculateEvent event = new GeofenceSlotRecalculateEvent(
                userId,
                new BigDecimal("37.5665"),
                new BigDecimal("126.9780"),
                new BigDecimal("90.0")
        );

        TodoCandidatePlace includedCandidate = createCandidate(101L, 201L, 301L, 120);
        TodoCandidatePlace missingDistanceCandidate = createCandidate(102L, 202L, 302L, 80);

        when(userPlaceRepository.findWithPlaceByUserId(userId)).thenReturn(List.of());
        when(todoCandidatePlaceRepository.findMonitoringCandidateDistancesByUserId(
                eq(userId),
                eq(37.5665),
                eq(126.9780)
        )).thenReturn(List.of(distanceProjection(101L, 55.0)));
        when(todoCandidatePlaceRepository.findAllWithTodoAndPlaceByIdIn(List.of(101L)))
                .thenReturn(List.of(includedCandidate, missingDistanceCandidate));
        when(geofenceSlotRepository.findByUserId(userId)).thenReturn(List.of());

        // when
        geofenceSlotManager.recalculateSlots(event);

        // then: 실시간 거리 없는 candidate(102)는 슬롯 upsert 대상에서 제외된다.
        verify(geofenceSlotRepository).upsertSlot(
                eq(userId),
                eq(301L),
                eq(201L),
                any(OffsetDateTime.class),
                eq(true)
        );
        verify(geofenceSlotRepository, never()).upsertSlot(
                eq(userId),
                eq(302L),
                eq(202L),
                any(OffsetDateTime.class),
                anyBoolean()
        );
        verify(geofenceSlotSseService).notifySlotsUpdated(eq(userId), any(OffsetDateTime.class));
    }

    @Test
    void recalculateSlots_limitsActiveSlotsToTwoPerTodo() {
        // given: 동일 todo 후보 3개 + 거리 projection 3개
        Long userId = 1L;
        GeofenceSlotRecalculateEvent event = new GeofenceSlotRecalculateEvent(
                userId,
                new BigDecimal("37.5665"),
                new BigDecimal("126.9780"),
                new BigDecimal("0.0")
        );

        TodoCandidatePlace c1 = createCandidate(201L, 901L, 301L, 50);
        TodoCandidatePlace c2 = createCandidate(202L, 901L, 302L, 60);
        TodoCandidatePlace c3 = createCandidate(203L, 901L, 303L, 70);

        when(userPlaceRepository.findWithPlaceByUserId(userId)).thenReturn(List.of());
        when(todoCandidatePlaceRepository.findMonitoringCandidateDistancesByUserId(
                eq(userId),
                eq(37.5665),
                eq(126.9780)
        )).thenReturn(List.of(
                distanceProjection(201L, 10.0),
                distanceProjection(202L, 20.0),
                distanceProjection(203L, 30.0)
        ));
        when(todoCandidatePlaceRepository.findAllWithTodoAndPlaceByIdIn(List.of(201L, 202L, 203L)))
                .thenReturn(List.of(c1, c2, c3));
        when(geofenceSlotRepository.findByUserId(userId)).thenReturn(List.of());

        // when
        geofenceSlotManager.recalculateSlots(event);

        // then: 동일 todo에서 상위 2개만 active=true, 나머지 1개는 active=false 처리된다.
        verify(geofenceSlotRepository).upsertSlot(eq(userId), eq(301L), eq(901L), any(OffsetDateTime.class), eq(true));
        verify(geofenceSlotRepository).upsertSlot(eq(userId), eq(302L), eq(901L), any(OffsetDateTime.class), eq(true));
        verify(geofenceSlotRepository).upsertSlot(eq(userId), eq(303L), eq(901L), any(OffsetDateTime.class), eq(false));
    }

    private TodoCandidatePlace createCandidate(Long candidateId, Long todoId, Long placeId, int distanceM) {
        Todo todo = Todo.builder()
                .id(todoId)
                .userId(1L)
                .inputType("TEXT")
                .todoType("SPECIFIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content("content")
                .alertEnabled(true)
                .build();

        Place place = Place.builder()
                .id(placeId)
                .name("place-" + placeId)
                .location(Place.toPoint(126.9780, 37.5665))
                .build();

        return TodoCandidatePlace.builder()
                .id(candidateId)
                .todo(todo)
                .place(place)
                .distanceM(distanceM)
                .isMonitoringTarget(true)
                .calculatedAt(OffsetDateTime.now())
                .build();
    }

    private TodoCandidateDistanceProjection distanceProjection(Long candidateId, Double distanceMeters) {
        return new TodoCandidateDistanceProjection() {
            @Override
            public Long getCandidateId() {
                return candidateId;
            }

            @Override
            public Double getDistanceMeters() {
                return distanceMeters;
            }
        };
    }
}
