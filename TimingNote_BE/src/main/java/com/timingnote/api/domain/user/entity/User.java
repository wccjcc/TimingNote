package com.timingnote.api.domain.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 디바이스 설치 단위 사용자를 저장하는 엔티티
 */
@Getter
@Entity
@NoArgsConstructor
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 앱 설치 단위 고유 식별자
    @Column(name = "installation_uuid", nullable = false, unique = true)
    private UUID installationUuid;

    // 요청 인증에 사용할 디바이스 시크릿
    @Column(name = "device_secret", nullable = false, length = 255)
    private String deviceSecret;

    @Column(name = "last_seen_at")
    private OffsetDateTime lastSeenAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    public User(UUID installationUuid, String deviceSecret) {
        this.installationUuid = installationUuid;
        this.deviceSecret = deviceSecret;
    }

    // 디바이스 시크릿 해시를 갱신한다.
    public void updateDeviceSecret(String deviceSecret) {
        this.deviceSecret = deviceSecret;
    }

    // 마지막 접속 시각을 갱신한다.
    public void updateLastSeenAt(OffsetDateTime lastSeenAt) {
        this.lastSeenAt = lastSeenAt;
    }

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now(ZoneOffset.UTC);
        }
    }
}
