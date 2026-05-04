package com.timingnote.api.domain.notification.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@NoArgsConstructor
@Table(name = "geofence_recalculate_outbox")
public class GeofenceRecalculateOutbox {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "course", precision = 7, scale = 3)
    private BigDecimal course;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private GeofenceOutboxStatus status;

    @Column(name = "retry_count", nullable = false)
    private int retryCount;

    @Column(name = "max_retry_count", nullable = false)
    private int maxRetryCount;

    @Column(name = "next_retry_at", nullable = false)
    private OffsetDateTime nextRetryAt;

    @Column(name = "last_error", columnDefinition = "TEXT")
    private String lastError;

    @Column(name = "published_at")
    private OffsetDateTime publishedAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public static GeofenceRecalculateOutbox create(
            Long userId,
            BigDecimal latitude,
            BigDecimal longitude,
            BigDecimal course,
            int maxRetryCount,
            OffsetDateTime now
    ) {
        GeofenceRecalculateOutbox outbox = new GeofenceRecalculateOutbox();
        outbox.userId = userId;
        outbox.latitude = latitude;
        outbox.longitude = longitude;
        outbox.course = course;
        outbox.status = GeofenceOutboxStatus.PENDING;
        outbox.retryCount = 0;
        outbox.maxRetryCount = maxRetryCount;
        outbox.nextRetryAt = now;
        outbox.createdAt = now;
        outbox.updatedAt = now;
        return outbox;
    }

    public void markProcessing(OffsetDateTime now) {
        this.status = GeofenceOutboxStatus.PROCESSING;
        this.updatedAt = now;
    }

    public void markPublished(OffsetDateTime now) {
        this.status = GeofenceOutboxStatus.PUBLISHED;
        this.publishedAt = now;
        this.updatedAt = now;
        this.lastError = null;
    }

    public void markRetry(String error, OffsetDateTime nextRetryAt, OffsetDateTime now) {
        this.retryCount = this.retryCount + 1;
        this.status = GeofenceOutboxStatus.RETRY;
        this.lastError = error;
        this.nextRetryAt = nextRetryAt;
        this.updatedAt = now;
    }

    public void markDlq(String error, OffsetDateTime now) {
        this.retryCount = this.retryCount + 1;
        this.status = GeofenceOutboxStatus.DLQ;
        this.lastError = error;
        this.updatedAt = now;
    }

    public boolean willExceedMaxRetry() {
        return (this.retryCount + 1) >= this.maxRetryCount;
    }
}
