package com.timingnote.api.domain.notification.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Geofence 재계산 요청 DTO.
 */
@Getter
@NoArgsConstructor
public class GeofenceRecalculateRequestDto {

    @NotNull
    @DecimalMin(value = "-90.0")
    @DecimalMax(value = "90.0")
    private BigDecimal latitude;

    @NotNull
    @DecimalMin(value = "-180.0")
    @DecimalMax(value = "180.0")
    private BigDecimal longitude;

    // iOS CLLocation.course 값(도 단위)
    private BigDecimal course;

    @NotNull
    private OffsetDateTime occurredAt;
}

