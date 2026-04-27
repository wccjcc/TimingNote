package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoInput;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TodoInputRepository extends JpaRepository<TodoInput, Long> {
}
