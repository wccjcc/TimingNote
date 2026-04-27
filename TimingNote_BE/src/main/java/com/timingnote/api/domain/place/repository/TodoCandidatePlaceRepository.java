package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TodoCandidatePlaceRepository extends JpaRepository<TodoCandidatePlace, Long> {

    List<TodoCandidatePlace> findByTodoId(Long todoId);
}
