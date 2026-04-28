package com.timingnote.api.domain.notification.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.entity.UserFcmToken;
import com.timingnote.api.domain.notification.entity.UserNotification;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.notification.repository.UserFcmTokenRepository;
import com.timingnote.api.domain.notification.repository.UserNotificationRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import java.time.OffsetDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * NOTI-05 위치 기반 알림 발송 서비스.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {

    private static final String TODO_STATUS_ACTIVE = "ACTIVE";
    private static final String NOTIFICATION_TYPE_GEOFENCE = "GEOFENCE";
    private static final String NOTIFICATION_STATUS_SENT = "SENT";
    private static final String NOTIFICATION_STATUS_FAILED = "FAILED";
    private static final long COOLDOWN_HOURS = 3L;

    private final GeofenceSlotRepository geofenceSlotRepository;
    private final TodoRepository todoRepository;
    private final UserFcmTokenRepository userFcmTokenRepository;
    private final UserNotificationRepository userNotificationRepository;
    private final FirebaseMessaging firebaseMessaging;

    @Override
    @Transactional
    public NotificationGeofenceSendResponseDto sendGeofenceNotification(Long userId, Long slotId) {
        GeofenceSlot slot = geofenceSlotRepository.findById(slotId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        if (!slot.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }

        Todo todo = todoRepository.findById(slot.getTodoId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        if (!isSendableTodo(todo)) {
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("TODO_NOT_SENDABLE")
                    .build();
        }

        UserFcmToken fcmToken = userFcmTokenRepository.findByUserId(userId).orElse(null);
        if (fcmToken == null || !Boolean.TRUE.equals(fcmToken.getIsActive())) {
            saveNotificationHistory(userId, todo.getId(), null, todo.getContent(), false);
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("FCM_TOKEN_NOT_AVAILABLE")
                    .build();
        }

        boolean sent = sendFcm(fcmToken.getFcmToken(), todo.getContent());
        saveNotificationHistory(userId, todo.getId(), null, todo.getContent(), sent);
        if (sent) {
            // 알림 발송 성공 시 3시간 쿨다운 적용
            todo.updateCooldownUntil(OffsetDateTime.now().plusHours(COOLDOWN_HOURS));
        }

        return NotificationGeofenceSendResponseDto.builder()
                .sent(sent)
                .reason(sent ? "SENT" : "FCM_SEND_FAILED")
                .build();
    }

    private boolean isSendableTodo(Todo todo) {
        if (!TODO_STATUS_ACTIVE.equals(todo.getStatus())) {
            return false;
        }
        if (!todo.isAlertEnabled()) {
            return false;
        }
        OffsetDateTime now = OffsetDateTime.now();
        if (todo.getSnoozedUntil() != null && todo.getSnoozedUntil().isAfter(now)) {
            return false;
        }
        return todo.getCooldownUntil() == null || !todo.getCooldownUntil().isAfter(now);
    }

    private boolean sendFcm(String token, String todoContent) {
        String title = "타이밍노트 알림";
        String body = todoContent == null || todoContent.isBlank()
                ? "위치 기반 알림이 도착했습니다."
                : todoContent;

        Message message = Message.builder()
                .setToken(token)
                .putData("type", NOTIFICATION_TYPE_GEOFENCE)
                .putData("title", title)
                .putData("body", body)
                .build();
        try {
            firebaseMessaging.send(message);
            return true;
        } catch (FirebaseMessagingException e) {
            log.warn("FCM send failed. tokenUserMessage={}", e.getMessage());
            return false;
        }
    }

    private void saveNotificationHistory(Long userId, Long todoId, Long candidatePlaceId, String todoContent, boolean sent) {
        UserNotification notification = UserNotification.builder()
                .userId(userId)
                .todoId(todoId)
                .candidatePlaceId(candidatePlaceId)
                .notificationType(NOTIFICATION_TYPE_GEOFENCE)
                .status(sent ? NOTIFICATION_STATUS_SENT : NOTIFICATION_STATUS_FAILED)
                .title("타이밍노트 알림")
                .body(todoContent)
                .build();
        userNotificationRepository.save(notification);
    }
}
