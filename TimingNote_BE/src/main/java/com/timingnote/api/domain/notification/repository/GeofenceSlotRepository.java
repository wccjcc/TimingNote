package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GeofenceSlotRepository extends JpaRepository<GeofenceSlot, Long> {

    List<GeofenceSlot> findByUserId(Long userId);

    @Modifying
    @Query(value = """
            INSERT INTO geofence_slots (user_id, place_id, todo_id, caculated_at, is_active)
            VALUES (:userId, :placeId, :todoId, :calculatedAt, :active)
            ON CONFLICT (user_id, todo_id, place_id)
            DO UPDATE SET
                caculated_at = EXCLUDED.caculated_at,
                is_active = EXCLUDED.is_active
            """, nativeQuery = true)
    void upsertSlot(
            @Param("userId") Long userId,
            @Param("placeId") Long placeId,
            @Param("todoId") Long todoId,
            @Param("calculatedAt") java.time.OffsetDateTime calculatedAt,
            @Param("active") boolean active
    );
}
