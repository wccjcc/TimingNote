package com.timingnote.api.domain.notification.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@NoArgsConstructor
@Table(name = "geofence_slots")
public class GeofenceSlot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(name = "todo_id", nullable = false)
    private Long todoId;

    @Column(name = "caculated_at", nullable = false)
    private OffsetDateTime calculatedAt;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    public static GeofenceSlot create(
            Long userId,
            Long placeId,
            Long todoId,
            OffsetDateTime calculatedAt,
            boolean active
    ) {
        GeofenceSlot slot = new GeofenceSlot();
        slot.userId = userId;
        slot.placeId = placeId;
        slot.todoId = todoId;
        slot.calculatedAt = calculatedAt;
        slot.active = active;
        return slot;
    }

    public void refresh(Long placeId, Long todoId, OffsetDateTime calculatedAt, boolean active) {
        this.placeId = placeId;
        this.todoId = todoId;
        this.calculatedAt = calculatedAt;
        this.active = active;
    }
}
