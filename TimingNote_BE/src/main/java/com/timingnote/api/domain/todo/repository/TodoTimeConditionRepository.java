package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TodoTimeConditionRepository extends JpaRepository<TodoTimeCondition, Long> {
}
