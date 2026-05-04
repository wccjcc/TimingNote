package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;

public interface GeofenceRecalculateService {

    GeofenceRecalculateResponseDto requestRecalculation(Long userId, GeofenceRecalculateRequestDto requestDto);
}

