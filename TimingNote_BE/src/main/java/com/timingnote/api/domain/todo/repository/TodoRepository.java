package com.timingnote.api.domain.todo.repository;

import com.timingnote.api.domain.todo.entity.Todo;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
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

    /**
     * 다중 소프트 삭제 — userId 조건 포함.
     * 반환값(영향 행 수)으로 소유권 검증: affected != ids.size() 이면 전체 롤백.
     */
    @Modifying
    @Query("UPDATE Todo t SET t.status = 'DELETED', t.deletedAt = :now " +
           "WHERE t.id IN :ids AND t.userId = :userId")
    int softDeleteByIdsAndUserId(@Param("ids") List<Long> ids,
                                  @Param("userId") Long userId,
                                  @Param("now") OffsetDateTime now);

    /**
     * 검색 인덱스 백필용 페이지네이션.
     * fromId보다 큰 todo를 id 오름차순으로 batchSize만큼 가져온다.
     * userId가 null이면 전체, 아니면 해당 사용자만.
     */
    @Query("""
            SELECT t FROM Todo t
            WHERE t.id > :fromId
              AND (:userId IS NULL OR t.userId = :userId)
            ORDER BY t.id ASC
            """)
    List<Todo> findForReindex(@Param("fromId") Long fromId,
                              @Param("userId") Long userId,
                              Pageable pageable);
}

