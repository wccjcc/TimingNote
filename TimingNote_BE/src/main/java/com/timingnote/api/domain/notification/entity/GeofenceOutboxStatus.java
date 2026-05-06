package com.timingnote.api.domain.notification.entity;

public enum GeofenceOutboxStatus {
    PENDING,
    PROCESSING,
    RETRY,
    PUBLISHED,
    DLQ
}

