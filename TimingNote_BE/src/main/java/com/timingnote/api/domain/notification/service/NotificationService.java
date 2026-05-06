package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.NotificationActionRequestDto;
import com.timingnote.api.domain.notification.dto.request.NotificationReadUpdateRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationActionResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationDeleteResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationHistoryResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationReadUpdateResponseDto;

public interface NotificationService {

    NotificationGeofenceSendResponseDto sendGeofenceNotification(Long userId, Long slotId);

    NotificationHistoryResponseDto getNotificationHistory(Long userId, Long todoId, int page, int size);

    NotificationActionResponseDto applyNotificationAction(Long userId, Long notificationId, NotificationActionRequestDto requestDto);

    NotificationReadUpdateResponseDto updateNotificationRead(
            Long userId,
            Long notificationId,
            NotificationReadUpdateRequestDto requestDto
    );

    NotificationDeleteResponseDto deleteNotification(Long userId, Long notificationId);
}
