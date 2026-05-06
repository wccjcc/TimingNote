package com.timingnote.api.domain.notification.dto.response;

import lombok.Builder;
import lombok.Getter;

/**
 * Geofence 재계산 요청 응답 DTO.
 */
@Getter
@Builder
public class GeofenceRecalculateResponseDto {

    private boolean accepted;
    private String status;
}

