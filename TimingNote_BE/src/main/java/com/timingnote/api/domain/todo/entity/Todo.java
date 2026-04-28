package com.timingnote.api.domain.todo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "todos")
public class Todo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "primary_place_id")
    private Long primaryPlaceId;

    @Column(name = "category", length = 20)
    private String category;

    @Column(name = "input_type", length = 20, nullable = false)
    private String inputType; // TEXT, VOICE, IMAGE, LINK

    @Column(name = "todo_type", length = 20, nullable = false)
    private String todoType; // SPECIFIC,GENERIC,ALIAS,GENERAL

    @Column(name = "status", length = 20, nullable = false)
    private String status; // ACTIVE, DELETED, DONE

    @Column(name = "structure_status", length = 20, nullable = false)
    private String structureStatus; // PENDING, READY, FAILED

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "resolved_place_label")
    private String resolvedPlaceLabel;

    @Column(name = "alert_enabled", nullable = false)
    private boolean alertEnabled;

    @Column(name = "snoozed_until")
    private OffsetDateTime snoozedUntil;

    @Column(name = "cooldown_until")
    private OffsetDateTime cooldownUntil;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Column(name = "deleted_at")
    private OffsetDateTime deletedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public void updateContent(String content) {
        this.content = content;
    }

    public void updateTodoType(String todoType) {
        this.todoType = todoType;
    }

    public void updateResolvedPlaceLabel(String label) {
        this.resolvedPlaceLabel = label;
    }

    public void updateStructureStatus(String structureStatus) {
        this.structureStatus = structureStatus;
    }

    public void updateCategory(String category) {
        this.category = category;
    }

    public void updatePrimaryPlaceId(Long primaryPlaceId) {
        this.primaryPlaceId = primaryPlaceId;
    }

    public void updateAlertEnabled(boolean alertEnabled) {
        this.alertEnabled = alertEnabled;
    }

    public void updateStatus(String status) {
        this.status = status;
        this.completedAt = "DONE".equals(status) ? OffsetDateTime.now() : null;
    }
    public void updateCooldownUntil(OffsetDateTime cooldownUntil) {
        this.cooldownUntil = cooldownUntil;
    }
}
