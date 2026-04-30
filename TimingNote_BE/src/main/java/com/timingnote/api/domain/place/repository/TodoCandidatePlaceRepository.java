package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TodoCandidatePlaceRepository extends JpaRepository<TodoCandidatePlace, Long> {

    List<TodoCandidatePlace> findByTodoId(Long todoId);

    @Modifying
    @Query("DELETE FROM TodoCandidatePlace tcp WHERE tcp.todo.id = :todoId")
    void deleteAllByTodo_Id(@Param("todoId") Long todoId);
}
