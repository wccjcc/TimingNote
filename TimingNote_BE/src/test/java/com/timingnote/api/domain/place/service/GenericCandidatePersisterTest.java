package com.timingnote.api.domain.place.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GenericCandidatePersisterTest {

    private static final double LATITUDE = 37.5665;
    private static final double LONGITUDE = 126.9780;
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-05-26T10:00:00+09:00");

    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    @InjectMocks
    private GenericCandidatePersister persister;

    @Test
    void persistOneTodo_reactivatesExisting_addsNewCandidate_andExpiresMissingCandidate() {
        Todo todo = todo();
        Place retainedPlace = place(100L, "기존 약국");
        Place missingPlace = place(200L, "사라진 약국");
        Place newPlace = place(300L, "새 약국");
        TodoCandidatePlace retainedCandidate = candidate(todo, retainedPlace, 500, NOW.minusHours(1));
        TodoCandidatePlace missingCandidate = candidate(todo, missingPlace, 100, null);
        when(todoCandidatePlaceRepository.findAllWithPlaceByTodoId(todo.getId()))
                .thenReturn(List.of(retainedCandidate, missingCandidate));

        persister.persistOneTodo(todo, List.of(retainedPlace, newPlace), LATITUDE, LONGITUDE, NOW);

        List<TodoCandidatePlace> savedCandidates = captureSavedCandidates();
        assertThat(savedCandidates).hasSize(3);
        assertThat(retainedCandidate.getDistanceM()).isZero();
        assertThat(retainedCandidate.getCalculatedAt()).isEqualTo(NOW);
        assertThat(retainedCandidate.getExpiresAt()).isNull();
        assertThat(missingCandidate.getExpiresAt()).isEqualTo(NOW);

        TodoCandidatePlace newCandidate = savedCandidates.stream()
                .filter(candidate -> candidate.getPlace().getId().equals(newPlace.getId()))
                .findFirst()
                .orElseThrow();
        assertThat(newCandidate.getTodo()).isSameAs(todo);
        assertThat(newCandidate.getDistanceM()).isZero();
        assertThat(newCandidate.isMonitoringTarget()).isTrue();
        assertThat(newCandidate.getCalculatedAt()).isEqualTo(NOW);
        assertThat(newCandidate.getExpiresAt()).isNull();
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private List<TodoCandidatePlace> captureSavedCandidates() {
        ArgumentCaptor<List> captor = ArgumentCaptor.forClass(List.class);
        verify(todoCandidatePlaceRepository).saveAll(captor.capture());
        return (List<TodoCandidatePlace>) captor.getValue();
    }

    private Todo todo() {
        return Todo.builder()
                .id(1L)
                .userId(10L)
                .category("HEALTH")
                .inputType("TEXT")
                .todoType("GENERIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content("약국 들르기")
                .resolvedPlaceLabel("약국")
                .alertEnabled(true)
                .build();
    }

    private TodoCandidatePlace candidate(Todo todo, Place place, int distanceM, OffsetDateTime expiresAt) {
        return TodoCandidatePlace.builder()
                .todo(todo)
                .place(place)
                .distanceM(distanceM)
                .isMonitoringTarget(true)
                .calculatedAt(NOW.minusHours(1))
                .expiresAt(expiresAt)
                .build();
    }

    private Place place(Long id, String name) {
        return Place.builder()
                .id(id)
                .name(name)
                .location(Place.toPoint(LONGITUDE, LATITUDE))
                .build();
    }
}
