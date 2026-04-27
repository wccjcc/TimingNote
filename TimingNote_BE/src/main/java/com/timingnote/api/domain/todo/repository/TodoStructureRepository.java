package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoStructure;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TodoStructureRepository extends JpaRepository<TodoStructure, Long> {
}
