package com.timingnote.api.domain.notification.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.entity.NotificationStatus;
import com.timingnote.api.domain.notification.entity.NotificationType;
import com.timingnote.api.domain.notification.entity.UserFcmToken;
import com.timingnote.api.domain.notification.entity.UserNotification;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.notification.repository.UserFcmTokenRepository;
import com.timingnote.api.domain.notification.repository.UserNotificationRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.enums.ConditionType;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
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
    private static final String FCM_DATA_TYPE_GEOFENCE = "GEOFENCE";
    private static final long COOLDOWN_HOURS = 3L;

    private final GeofenceSlotRepository geofenceSlotRepository;
    private final TodoRepository todoRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
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

        List<TodoTimeCondition> timeConditions = todoTimeConditionRepository.findAllByTodo_Id(todo.getId());
        if (!isSendableTodo(todo, timeConditions)) {
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("TODO_NOT_SENDABLE")
                    .build();
        }

        UserFcmToken fcmToken = userFcmTokenRepository.findByUserId(userId).orElse(null);
        if (fcmToken == null || !Boolean.TRUE.equals(fcmToken.getIsActive())) {
            saveNotificationHistory(userId, todo, null, todo.getContent(), false);
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("FCM_TOKEN_NOT_AVAILABLE")
                    .build();
        }

        boolean sent = sendFcm(fcmToken.getFcmToken(), todo.getContent());
        saveNotificationHistory(userId, todo, null, todo.getContent(), sent);

        if (sent) {
            todo.updateCooldownUntil(OffsetDateTime.now().plusHours(COOLDOWN_HOURS));
        }

        return NotificationGeofenceSendResponseDto.builder()
                .sent(sent)
                .reason(sent ? "SENT" : "FCM_SEND_FAILED")
                .build();
    }

    private boolean isSendableTodo(Todo todo, List<TodoTimeCondition> timeConditions) {
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
        if (todo.getCooldownUntil() != null && todo.getCooldownUntil().isAfter(now)) {
            return false;
        }

        return matchesTimeConditions(timeConditions, now);
    }

    private boolean matchesTimeConditions(List<TodoTimeCondition> conditions, OffsetDateTime now) {
        if (conditions == null || conditions.isEmpty()) {
            return true;
        }
        for (TodoTimeCondition condition : conditions) {
            if (!matchesSingleCondition(condition, now)) {
                return false;
            }
        }
        return true;
    }

    private boolean matchesSingleCondition(TodoTimeCondition condition, OffsetDateTime now) {
        ConditionType type = condition.getConditionType();
        if (type == null) {
            return true;
        }

        LocalDate today = now.toLocalDate();
        LocalTime currentTime = now.toLocalTime();

        return switch (type) {
            case DATE -> condition.getStartDate() == null || !today.isBefore(condition.getStartDate());
            case DATE_RANGE -> isWithinDateRange(today, condition.getStartDate(), condition.getEndDate());
            case WEEK -> matchesWeekBitmask(today.getDayOfWeek(), condition.getDaysOfWeek());
            case TIME_RANGE -> isWithinTimeRange(currentTime, condition.getStartTime(), condition.getEndTime());
            default -> true;
        };
    }

    private boolean isWithinDateRange(LocalDate target, LocalDate start, LocalDate end) {
        if (start != null && target.isBefore(start)) {
            return false;
        }
        return end == null || !target.isAfter(end);
    }

    private boolean matchesWeekBitmask(DayOfWeek dayOfWeek, Short daysOfWeekMask) {
        if (daysOfWeekMask == null) {
            return true;
        }
        int dayBit = switch (dayOfWeek) {
            case MONDAY -> 1;
            case TUESDAY -> 2;
            case WEDNESDAY -> 4;
            case THURSDAY -> 8;
            case FRIDAY -> 16;
            case SATURDAY -> 32;
            case SUNDAY -> 64;
        };
        return (daysOfWeekMask & dayBit) == dayBit;
    }

    private boolean isWithinTimeRange(LocalTime target, LocalTime start, LocalTime end) {
        if (start == null && end == null) {
            return true;
        }
        if (start != null && end != null && end.isBefore(start)) {
            return !target.isBefore(start) || !target.isAfter(end);
        }
        if (start != null && target.isBefore(start)) {
            return false;
        }
        return end == null || !target.isAfter(end);
    }

    private boolean sendFcm(String token, String todoContent) {
        String title = "타이밍노트 알림";
        String body = (todoContent == null || todoContent.isBlank())
                ? "위치 기반 알림이 도착했습니다."
                : todoContent;

        Message message = Message.builder()
                .setToken(token)
                .putData("type", FCM_DATA_TYPE_GEOFENCE)
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

    private void saveNotificationHistory(Long userId, Todo todo, Long candidatePlaceId, String todoContent, boolean sent) {
        NotificationType notificationType = resolveNotificationType(todo);
        NotificationStatus notificationStatus = sent ? NotificationStatus.SENT : NotificationStatus.FAILED;

        UserNotification notification = UserNotification.builder()
                .userId(userId)
                .todoId(todo.getId())
                .candidatePlaceId(candidatePlaceId)
                .notificationType(notificationType)
                .status(notificationStatus)
                .title("타이밍노트 알림")
                .body(todoContent)
                .build();
        userNotificationRepository.save(notification);
    }

    private NotificationType resolveNotificationType(Todo todo) {
        String todoType = todo.getTodoType();
        if (todoType == null) {
            return NotificationType.GENERIC;
        }
        return switch (todoType) {
            case "SPECIFIC" -> NotificationType.SPECIFIC;
            case "GENERIC", "ALIAS", "GENERAL" -> NotificationType.GENERIC;
            default -> NotificationType.GENERIC;
        };
    }
}
