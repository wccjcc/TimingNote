package com.timingnote.api.domain.todo.search.service;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Todo + Place 데이터를 ES 도큐먼트로 조립한다.
 *
 * <p>외부 @Service로 분리한 의도: 색인 호출자({@code TodoIndexerImpl})는 boundedElastic 스레드에서 동작하며,
 * 동일 클래스 메서드 호출은 AOP 프록시를 거치지 않아 @Transactional이 무력화된다.
 * 외부 빈으로 분리하면 readOnly 트랜잭션이 정상 시작된다 (TodoStructurePersister 분리 패턴과 동일).
 */
@Service
@RequiredArgsConstructor
public class TodoDocumentAssembler {

    private final TodoRepository todoRepository;
    private final PlaceRepository placeRepository;

    @Transactional(readOnly = true)
    public Optional<TodoSearchDocument> assemble(Long todoId) {
        return todoRepository.findById(todoId).map(this::toDocumentSingle);
    }

    /**
     * 다수 Todo를 일괄 조립. Place는 한 번에 IN 조회.
     */
    @Transactional(readOnly = true)
    public List<TodoSearchDocument> assembleBatch(List<Todo> todos) {
        if (todos.isEmpty()) return List.of();

        Set<Long> placeIds = todos.stream()
                .map(Todo::getPrimaryPlaceId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Map<Long, String> placeNames = placeIds.isEmpty()
                ? Map.of()
                : placeRepository.findAllById(placeIds).stream()
                        .collect(Collectors.toMap(Place::getId, Place::getName));

        return todos.stream()
                .map(todo -> toDocument(todo, placeNames))
                .toList();
    }

    private TodoSearchDocument toDocumentSingle(Todo todo) {
        String placeName = todo.getPrimaryPlaceId() != null
                ? placeRepository.findById(todo.getPrimaryPlaceId()).map(Place::getName).orElse(null)
                : null;
        return build(todo, placeName);
    }

    private TodoSearchDocument toDocument(Todo todo, Map<Long, String> placeNames) {
        String placeName = todo.getPrimaryPlaceId() != null
                ? placeNames.get(todo.getPrimaryPlaceId())
                : null;
        return build(todo, placeName);
    }

    private TodoSearchDocument build(Todo todo, String placeName) {
        return TodoSearchDocument.builder()
                .id(String.valueOf(todo.getId()))
                .userId(String.valueOf(todo.getUserId()))
                .content(todo.getContent())
                .placeLabel(todo.getResolvedPlaceLabel())
                .placeName(placeName)
                .status(todo.getStatus())
                .category(todo.getCategory())
                .todoType(todo.getTodoType())
                .structureStatus(todo.getStructureStatus())
                .primaryPlaceId(todo.getPrimaryPlaceId())
                .createdAt(todo.getCreatedAt())
                .completedAt(todo.getCompletedAt())
                .deletedAt(todo.getDeletedAt())
                .build();
    }
}
