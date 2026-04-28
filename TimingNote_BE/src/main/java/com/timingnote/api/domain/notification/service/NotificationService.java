package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;

public interface NotificationService {

    NotificationGeofenceSendResponseDto sendGeofenceNotification(Long userId, Long slotId);
}
