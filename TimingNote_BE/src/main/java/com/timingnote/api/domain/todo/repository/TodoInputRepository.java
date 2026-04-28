package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoInput;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TodoInputRepository extends JpaRepository<TodoInput, Long> {

    List<TodoInput> findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(List<Long> todoIds);

    List<TodoInput> findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(Long todoId);

    Optional<TodoInput> findFirstByTodo_IdAndSharedUrlIsNotNull(Long todoId);
}
