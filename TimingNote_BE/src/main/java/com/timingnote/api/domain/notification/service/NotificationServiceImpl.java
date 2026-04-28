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
 *
 * <p>처리 순서:
 * 1) geofence slot 존재/소유자 검증
 * 2) slot에 연결된 todo 조회
 * 3) todo 기본 상태 + todo_time_conditions 검증
 * 4) FCM 토큰 확인 후 푸시 전송 시도
 * 5) notifications 이력 저장
 * 6) 전송 성공 시 cooldown_until 3시간 갱신
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
        // 1) slot 존재 확인
        GeofenceSlot slot = geofenceSlotRepository.findById(slotId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        // 2) 본인 slot만 처리 허용
        if (!slot.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND);
        }

        // 3) slot 연결 todo 조회
        Todo todo = todoRepository.findById(slot.getTodoId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        List<TodoTimeCondition> timeConditions = todoTimeConditionRepository.findByTodoId(todo.getId());
        if (!isSendableTodo(todo, timeConditions)) {
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("TODO_NOT_SENDABLE")
                    .build();
        }

        // 4) 활성 FCM 토큰 확인
        UserFcmToken fcmToken = userFcmTokenRepository.findByUserId(userId).orElse(null);
        if (fcmToken == null || !Boolean.TRUE.equals(fcmToken.getIsActive())) {
            saveNotificationHistory(userId, todo, null, todo.getContent(), false);
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("FCM_TOKEN_NOT_AVAILABLE")
                    .build();
        }

        // 5) FCM 전송 + 이력 저장
        boolean sent = sendFcm(fcmToken.getFcmToken(), todo.getContent());
        saveNotificationHistory(userId, todo, null, todo.getContent(), sent);

        // 6) 성공 시 3시간 쿨다운 부여
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

        // 시간 조건은 모두 만족(AND)해야 발송 가능
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
        String type = condition.getConditionType();
        if (type == null || type.isBlank()) {
            return true;
        }

        LocalDate today = now.toLocalDate();
        LocalTime currentTime = now.toLocalTime();
        return switch (type) {
            case "DATE" -> condition.getStartDate() == null || !today.isBefore(condition.getStartDate());
            case "DATE_RANGE" -> isWithinDateRange(today, condition.getStartDate(), condition.getEndDate());
            case "WEEK" -> matchesWeekBitmask(today.getDayOfWeek(), condition.getDaysOfWeek());
            case "TIME_RANGE" -> isWithinTimeRange(currentTime, condition.getStartTime(), condition.getEndTime());
            default -> true;
        };
    }

    private boolean isWithinDateRange(LocalDate target, LocalDate start, LocalDate end) {
        if (start != null && target.isBefore(start)) {
            return false;
        }
        return end == null || !target.isAfter(end);
    }

    /**
     * days_of_week 비트마스크 판정.
     * MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64
     */
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
        // 자정 넘김 처리 (예: 22:00~02:00)
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
        String body = todoContent == null || todoContent.isBlank()
                ? "위치 기반 알림이 도착했습니다."
                : todoContent;

        Message message = Message.builder()
                .setToken(token)
                // 앱 라우팅 용도로 기존 payload type 유지
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

    /**
     * todo_type 매핑:
     * SPECIFIC -> SPECIFIC
     * GENERIC/ALIAS/GENERAL -> GENERIC
     */
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
