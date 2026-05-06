package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.Todo;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TodoRepository extends JpaRepository<Todo, Long> {

    @Query("""
            SELECT t FROM Todo t
            WHERE t.userId = :userId
              AND t.status <> 'DELETED'
              AND (:status IS NULL OR t.status = :status)
              AND (:category IS NULL OR t.category = :category)
              AND (:placeType IS NULL OR t.todoType = :placeType)
              AND (:cursor IS NULL OR t.id < :cursor)
            ORDER BY t.id DESC
            """)
    List<Todo> findTodoPage(
            @Param("userId") Long userId,
            @Param("status") String status,
            @Param("category") String category,
            @Param("placeType") String placeType,
            @Param("cursor") Long cursor,
            Pageable pageable
    );

    @Query("""
            SELECT t FROM Todo t
            WHERE t.userId = :userId
              AND t.status = 'ACTIVE'
              AND t.todoType = 'GENERIC'
              AND t.resolvedPlaceLabel IS NOT NULL
            """)
    List<Todo> findActiveGenericTodosByUserId(@Param("userId") Long userId);
}

