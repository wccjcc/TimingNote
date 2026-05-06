package com.timingnote.api.domain.notification.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 알림 발송 이력 엔티티.
 */
@Getter
@Entity
@NoArgsConstructor
@Table(name = "notifications")
public class UserNotification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "todo_id", nullable = false)
    private Long todoId;

    @Column(name = "candidate_place_id")
    private Long candidatePlaceId;

    @Column(name = "notification_type", nullable = false, length = 20)
    @Enumerated(EnumType.STRING)
    private NotificationType notificationType;

    @Column(name = "status", nullable = false, length = 20)
    @Enumerated(EnumType.STRING)
    private NotificationStatus status;

    @Column(name = "title", length = 255)
    private String title;

    @Column(name = "body")
    private String body;

    @Column(name = "opened_at")
    private OffsetDateTime openedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Builder
    public UserNotification(
            Long userId,
            Long todoId,
            Long candidatePlaceId,
            NotificationType notificationType,
            NotificationStatus status,
            String title,
            String body
    ) {
        this.userId = userId;
        this.todoId = todoId;
        this.candidatePlaceId = candidatePlaceId;
        this.notificationType = notificationType;
        this.status = status;
        this.title = title;
        this.body = body;
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now(ZoneOffset.UTC);
        }
    }

    // 알림 읽음(OPEN/DISMISS) 처리 시 상태와 시각을 함께 갱신한다.
    public void markOpened(OffsetDateTime openedAt) {
        this.status = NotificationStatus.OPENED;
        this.openedAt = openedAt;
    }
}
