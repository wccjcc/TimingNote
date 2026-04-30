package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.response.GeofenceSlotsResponseDto;

public interface GeofenceSlotQueryService {

    GeofenceSlotsResponseDto getActiveSlots(Long userId);
}
