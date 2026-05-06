package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.TodoInput;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TodoInputRepository extends JpaRepository<TodoInput, Long> {

    List<TodoInput> findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(List<Long> todoIds);

    List<TodoInput> findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(Long todoId);

    Optional<TodoInput> findFirstByTodo_IdAndSharedUrlIsNotNull(Long todoId);

    @Modifying
    @Query("DELETE FROM TodoInput ti WHERE ti.todo.id = :todoId AND ti.imageUrl IS NOT NULL")
    void deleteAllByTodo_IdAndImageUrlIsNotNull(@Param("todoId") Long todoId);

    @Modifying
    @Query("DELETE FROM TodoInput ti WHERE ti.todo.id = :todoId AND ti.sharedUrl IS NOT NULL")
    void deleteAllByTodo_IdAndSharedUrlIsNotNull(@Param("todoId") Long todoId);
}
