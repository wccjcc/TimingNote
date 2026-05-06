package com.timingnote.api.domain.settings.entity;

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
 * 사용자 알림 기본 설정 엔티티
 */
@Getter
@Entity
@NoArgsConstructor
@Table(name = "user_settings")
public class UserSettings {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "location_alert_enabled", nullable = false)
    private Boolean locationAlertEnabled;

    @Column(name = "push_alert_enabled", nullable = false)
    private Boolean pushAlertEnabled;

    @Column(name = "radius_m", nullable = false)
    private Integer radiusM;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public UserSettings(Long userId, Boolean locationAlertEnabled, Boolean pushAlertEnabled, Integer radiusM) {
        this.userId = userId;
        this.locationAlertEnabled = locationAlertEnabled;
        this.pushAlertEnabled = pushAlertEnabled;
        this.radiusM = radiusM;
    }

    // 등록/재등록 시 알림 기본값을 반영한다.
    public void apply(Boolean locationAlertEnabled, Boolean pushAlertEnabled, Integer radiusM) {
        this.locationAlertEnabled = locationAlertEnabled;
        this.pushAlertEnabled = pushAlertEnabled;
        this.radiusM = radiusM;
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
