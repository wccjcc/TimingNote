package com.timingnote.api.domain.todo.search.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class TodoDocumentAssemblerTest {

    private static final OffsetDateTime CREATED_AT = OffsetDateTime.parse("2026-05-26T10:00:00+09:00");
    private static final OffsetDateTime COMPLETED_AT = OffsetDateTime.parse("2026-05-26T11:00:00+09:00");
    private static final OffsetDateTime DELETED_AT = OffsetDateTime.parse("2026-05-26T12:00:00+09:00");

    @Mock
    private TodoRepository todoRepository;

    @Mock
    private PlaceRepository placeRepository;

    @InjectMocks
    private TodoDocumentAssembler assembler;

    @Test
    void assemble_returnsEmptyOptional_when_todoDoesNotExist() {
        when(todoRepository.findById(1L)).thenReturn(Optional.empty());

        Optional<TodoSearchDocument> result = assembler.assemble(1L);

        assertThat(result).isEmpty();
        verify(placeRepository, never()).findById(any());
    }

    @Test
    void assemble_buildsDocumentWithPlaceName_when_primaryPlaceExists() {
        Todo todo = todo(1L, 10L, 100L, "약국 들르기");
        Place place = place(100L, "Timing 약국");
        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(placeRepository.findById(100L)).thenReturn(Optional.of(place));

        Optional<TodoSearchDocument> result = assembler.assemble(1L);

        assertThat(result).isPresent();
        assertDocument(result.get(), todo, "Timing 약국");
    }

    @Test
    void assemble_buildsDocumentWithNullPlaceName_when_primaryPlaceMissing() {
        Todo todo = todo(1L, 10L, 100L, "약국 들르기");
        when(todoRepository.findById(1L)).thenReturn(Optional.of(todo));
        when(placeRepository.findById(100L)).thenReturn(Optional.empty());

        Optional<TodoSearchDocument> result = assembler.assemble(1L);

        assertThat(result).isPresent();
        assertDocument(result.get(), todo, null);
    }

    @Test
    void assembleBatch_returnsEmptyList_when_todosAreEmpty() {
        List<TodoSearchDocument> result = assembler.assembleBatch(List.of());

        assertThat(result).isEmpty();
        verify(placeRepository, never()).findAllById(any());
    }

    @Test
    void assembleBatch_loadsPlacesOnceAndMapsEachTodo() {
        Todo todoWithPlace = todo(1L, 10L, 100L, "약국 들르기");
        Todo todoWithoutPlace = todo(2L, 10L, null, "일반 메모 정리");
        Todo todoWithMissingPlace = todo(3L, 10L, 300L, "편의점 가기");
        when(placeRepository.findAllById(any())).thenReturn(List.of(place(100L, "Timing 약국")));

        List<TodoSearchDocument> result = assembler.assembleBatch(List.of(
                todoWithPlace,
                todoWithoutPlace,
                todoWithMissingPlace
        ));

        assertThat(result).hasSize(3);
        assertDocument(result.get(0), todoWithPlace, "Timing 약국");
        assertDocument(result.get(1), todoWithoutPlace, null);
        assertDocument(result.get(2), todoWithMissingPlace, null);
        verify(placeRepository).findAllById(any());
    }

    private void assertDocument(TodoSearchDocument document, Todo todo, String placeName) {
        assertThat(document.getId()).isEqualTo(String.valueOf(todo.getId()));
        assertThat(document.getUserId()).isEqualTo(String.valueOf(todo.getUserId()));
        assertThat(document.getContent()).isEqualTo(todo.getContent());
        assertThat(document.getPlaceLabel()).isEqualTo(todo.getResolvedPlaceLabel());
        assertThat(document.getPlaceName()).isEqualTo(placeName);
        assertThat(document.getStatus()).isEqualTo(todo.getStatus());
        assertThat(document.getCategory()).isEqualTo(todo.getCategory());
        assertThat(document.getTodoType()).isEqualTo(todo.getTodoType());
        assertThat(document.getStructureStatus()).isEqualTo(todo.getStructureStatus());
        assertThat(document.getPrimaryPlaceId()).isEqualTo(todo.getPrimaryPlaceId());
        assertThat(document.getCreatedAt()).isEqualTo(todo.getCreatedAt());
        assertThat(document.getCompletedAt()).isEqualTo(todo.getCompletedAt());
        assertThat(document.getDeletedAt()).isEqualTo(todo.getDeletedAt());
    }

    private Todo todo(Long id, Long userId, Long primaryPlaceId, String content) {
        return Todo.builder()
                .id(id)
                .userId(userId)
                .primaryPlaceId(primaryPlaceId)
                .category("HEALTH")
                .inputType("TEXT")
                .todoType(primaryPlaceId == null ? "GENERAL" : "SPECIFIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content(content)
                .resolvedPlaceLabel(primaryPlaceId == null ? null : "약국")
                .alertEnabled(true)
                .createdAt(CREATED_AT)
                .completedAt(COMPLETED_AT)
                .deletedAt(DELETED_AT)
                .build();
    }

    private Place place(Long id, String name) {
        return Place.builder()
                .id(id)
                .name(name)
                .location(Place.toPoint(126.9780, 37.5665))
                .build();
    }
}
