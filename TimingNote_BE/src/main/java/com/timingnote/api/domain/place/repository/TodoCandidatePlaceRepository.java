package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.projection.TodoCandidateDistanceProjection;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TodoCandidatePlaceRepository extends JpaRepository<TodoCandidatePlace, Long> {

    List<TodoCandidatePlace> findByTodoId(Long todoId);

    @Query("""
            SELECT tcp FROM TodoCandidatePlace tcp
            JOIN FETCH tcp.place
            WHERE tcp.todo.id = :todoId
            """)
    List<TodoCandidatePlace> findAllWithPlaceByTodoId(@Param("todoId") Long todoId);

    @Modifying
    @Query("DELETE FROM TodoCandidatePlace tcp WHERE tcp.todo.id = :todoId")
    void deleteAllByTodo_Id(@Param("todoId") Long todoId);

    @Query("""
            SELECT tcp
            FROM TodoCandidatePlace tcp
            JOIN FETCH tcp.todo t
            JOIN FETCH tcp.place p
            WHERE t.userId = :userId
              AND t.status = 'ACTIVE'
              AND tcp.isMonitoringTarget = true
              AND (tcp.expiresAt IS NULL OR tcp.expiresAt > :now)
            """)
    List<TodoCandidatePlace> findMonitoringCandidatesByUserId(@Param("userId") Long userId, @Param("now") OffsetDateTime now);

    @Query("""
            SELECT tcp
            FROM TodoCandidatePlace tcp
            JOIN FETCH tcp.todo t
            JOIN FETCH tcp.place p
            WHERE tcp.id IN :ids
            """)
    List<TodoCandidatePlace> findAllWithTodoAndPlaceByIdIn(@Param("ids") List<Long> ids);

    @Query(value = """
            SELECT
                tcp.id AS candidateId,
                ST_Distance(
                    p.location,
                    ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography
                ) AS distanceMeters
            FROM todo_candidate_places tcp
            JOIN todos t ON t.id = tcp.todo_id
            JOIN places p ON p.id = tcp.place_id
            WHERE t.user_id = :userId
              AND t.status = 'ACTIVE'
              AND tcp.is_monitoring_target = true
              AND (tcp.expires_at IS NULL OR tcp.expires_at > NOW())
            """, nativeQuery = true)
    List<TodoCandidateDistanceProjection> findMonitoringCandidateDistancesByUserId(
            @Param("userId") Long userId,
            @Param("latitude") double latitude,
            @Param("longitude") double longitude
    );
}
