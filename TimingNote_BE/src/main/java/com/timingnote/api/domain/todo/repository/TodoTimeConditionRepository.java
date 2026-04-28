package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TodoTimeConditionRepository extends JpaRepository<TodoTimeCondition, Long> {

    List<TodoTimeCondition> findByTodoId(Long todoId);
}
