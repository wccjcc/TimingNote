package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TodoTimeConditionRepository extends JpaRepository<TodoTimeCondition, Long> {

    List<TodoTimeCondition> findAllByTodo_Id(Long todoId);

    @Modifying
    @Query("DELETE FROM TodoTimeCondition tc WHERE tc.todo.id = :todoId")
    void deleteAllByTodo_Id(@Param("todoId") Long todoId);
}
