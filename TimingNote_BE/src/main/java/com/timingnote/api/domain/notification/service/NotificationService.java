package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.NotificationActionRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationActionResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationHistoryResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;

public interface NotificationService {

    NotificationGeofenceSendResponseDto sendGeofenceNotification(Long userId, Long slotId);

    NotificationHistoryResponseDto getNotificationHistory(Long userId, Long todoId, int page, int size);

    NotificationActionResponseDto applyNotificationAction(Long userId, Long notificationId, NotificationActionRequestDto requestDto);
}
