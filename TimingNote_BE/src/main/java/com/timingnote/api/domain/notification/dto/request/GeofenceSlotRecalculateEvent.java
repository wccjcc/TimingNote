package com.timingnote.api.domain.notification.dto.request;

import java.math.BigDecimal;

public record GeofenceSlotRecalculateEvent(
        Long userId,
        BigDecimal latitude,
        BigDecimal longitude,
        // iOS CLLocation.course 값(이동 방향, degree)
        BigDecimal course
) {
}
