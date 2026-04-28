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

/**
 * Geofence 감시 슬롯 엔티티.
 */
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

    // DB 스키마의 오탈자(caculated_at)를 그대로 매핑한다.
    @Column(name = "caculated_at", nullable = false)
    private OffsetDateTime calculatedAt;

    @Column(name = "is_active", nullable = false)
    private boolean active;
}
