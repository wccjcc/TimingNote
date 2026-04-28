package com.timingnote.api.domain.notification.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 사용자 FCM 토큰 저장 엔티티
 */
@Getter
@Entity
@NoArgsConstructor
@Table(name = "user_fcm_tokens")
public class UserFcmToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "fcm_token", nullable = false, length = 255)
    private String fcmToken;

    @Column(name = "platform", nullable = false, length = 20)
    private String platform;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public UserFcmToken(Long userId, String fcmToken, String platform, Boolean isActive) {
        this.userId = userId;
        this.fcmToken = fcmToken;
        this.platform = platform;
        this.isActive = isActive;
    }

    // 토큰 upsert 시 사용자/토큰/상태를 최신 값으로 갱신한다.
    public void apply(Long userId, String fcmToken, String platform, Boolean isActive) {
        this.userId = userId;
        this.fcmToken = fcmToken;
        this.platform = platform;
        this.isActive = isActive;
    }

    @PrePersist
    protected void onCreate() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = OffsetDateTime.now(ZoneOffset.UTC);
    }
}
