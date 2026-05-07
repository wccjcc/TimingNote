package com.timingnote.api.domain.notification.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.notification.dto.request.NotificationActionRequestDto;
import com.timingnote.api.domain.notification.dto.request.NotificationActionType;
import com.timingnote.api.domain.notification.dto.request.NotificationReadUpdateRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationActionResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationDeleteResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationHistoryItemResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationHistoryResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationReadUpdateResponseDto;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.entity.NotificationStatus;
import com.timingnote.api.domain.notification.entity.NotificationType;
import com.timingnote.api.domain.notification.entity.UserFcmToken;
import com.timingnote.api.domain.notification.entity.UserNotification;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.notification.repository.UserFcmTokenRepository;
import com.timingnote.api.domain.notification.repository.UserNotificationRepository;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.enums.ConditionType;
import com.timingnote.api.domain.todo.enums.TodoStatus;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

import com.timingnote.api.infra.client.fcm.PushNotificationSender;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {

    private static final String TODO_STATUS_ACTIVE = "ACTIVE";
    private static final String PUSH_TYPE_GEOFENCE = "GEOFENCE";
    private static final String IOS_CATEGORY_GEOFENCE_TODO_ACTIONS = "GEOFENCE_TODO_ACTIONS";
    private static final String TITLE_SUFFIX = "근처에요";
    private static final String TITLE_FALLBACK = "타이밍노트 알림";
    private static final String BODY_FALLBACK = "위치 기반 알림이 도착했습니다.";
    private static final long COOLDOWN_HOURS = 3L;

    private final GeofenceSlotRepository geofenceSlotRepository;
    private final TodoRepository todoRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
    private final UserFcmTokenRepository userFcmTokenRepository;
    private final UserNotificationRepository userNotificationRepository;
    private final PlaceRepository placeRepository;
    private final PushNotificationSender pushNotificationSender;
    private final GeofenceRecalculateOutboxService geofenceRecalculateOutboxService;

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
            String title = buildTitle(slot.getPlaceId());
            String body = buildBody(todo.getContent());
            UserNotification history = saveNotificationHistory(userId, todo, null, title, body, false);
            history.markFailed();
            return NotificationGeofenceSendResponseDto.builder()
                    .sent(false)
                    .reason("FCM_TOKEN_NOT_AVAILABLE")
                    .build();
        }

        String title = buildTitle(slot.getPlaceId());
        String body = buildBody(todo.getContent());
        UserNotification history = saveNotificationHistory(userId, todo, null, title, body, false);
        Map<String, String> pushData = Map.of(
                "notificationId", String.valueOf(history.getId()),
                "todoId", String.valueOf(todo.getId()),
                "slotId", String.valueOf(slot.getId()),
                "type", PUSH_TYPE_GEOFENCE
        );
        boolean sent = pushNotificationSender.send(
                fcmToken.getFcmToken(),
                PUSH_TYPE_GEOFENCE,
                title,
                body,
                pushData,
                IOS_CATEGORY_GEOFENCE_TODO_ACTIONS
        );
        if (sent) {
            history.markSent();
        } else {
            history.markFailed();
        }
        log.info(
                "Notification sent result userId={} slotId={} todoId={} sent={} title='{}' body='{}'",
                userId, slotId, todo.getId(), sent, title, body
        );

        if (sent) {
            todo.updateCooldownUntil(OffsetDateTime.now().plusHours(COOLDOWN_HOURS));
        }

        return NotificationGeofenceSendResponseDto.builder()
                .sent(sent)
                .reason(sent ? "SENT" : "FCM_SEND_FAILED")
                .build();
    }

    /**
     * NOTI-01 알림 이력 목록 조회.
     */
    @Override
    @Transactional(readOnly = true)
    public NotificationHistoryResponseDto getNotificationHistory(Long userId, Long todoId, int page, int size) {
        // 파라미터 예외 처리: 잘못된 요청은 400으로 응답
        if (page < 0 || size < 1 || size > 100) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }

        Pageable pageable = PageRequest.of(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "id"))
        );

        Page<UserNotification> notifications = (todoId == null)
                ? userNotificationRepository.findByUserId(userId, pageable)
                : userNotificationRepository.findByUserIdAndTodoId(userId, todoId, pageable);

        Page<NotificationHistoryItemResponseDto> mapped = notifications.map(NotificationHistoryItemResponseDto::from);
        return NotificationHistoryResponseDto.from(mapped);
    }

    /**
     * NOTI-02 알림 액션 처리.
     */
    @Override
    @Transactional
    public NotificationActionResponseDto applyNotificationAction(
            Long userId,
            Long notificationId,
            NotificationActionRequestDto requestDto
    ) {
        UserNotification notification = userNotificationRepository.findByIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
        Todo todo = todoRepository.findById(notification.getTodoId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        NotificationActionType actionType = requestDto.getActionType();
        OffsetDateTime now = OffsetDateTime.now();

        return switch (actionType) {
            case OPEN -> {
                notification.markOpened(now);
                yield NotificationActionResponseDto.builder()
                        .actionType(actionType.name())
                        .todoStatus(null)
                        .snoozedUntil(null)
                        .build();
            }
            case COMPLETE -> {
                notification.markOpened(now);
                todo.updateStatus(TodoStatus.DONE.name());
                // COMPLETE 처리 시점에만 geofence 재계산 outbox 이벤트를 적재합니다.
                // 위치 정보는 프론트에서 항상 전달하되, 값이 없으면 null로 적재됩니다.
                geofenceRecalculateOutboxService.enqueue(
                        userId,
                        requestDto.getLatitude(),
                        requestDto.getLongitude(),
                        requestDto.getCourse()
                );
                yield NotificationActionResponseDto.builder()
                        .actionType(actionType.name())
                        .todoStatus(todo.getStatus())
                        .snoozedUntil(null)
                        .build();
            }
            case SNOOZE -> {
                int snoozeMinutes = resolveSnoozeMinutes(requestDto.getSnoozeMinutes());
                notification.markOpened(now);
                OffsetDateTime snoozedUntil = now.plusMinutes(snoozeMinutes);
                todo.updateSnoozedUntil(snoozedUntil);
                yield NotificationActionResponseDto.builder()
                        .actionType(actionType.name())
                        .todoStatus(null)
                        .snoozedUntil(snoozedUntil)
                        .build();
            }
            case DISMISS -> {
                notification.markOpened(now);
                yield NotificationActionResponseDto.builder()
                        .actionType(actionType.name())
                        .todoStatus(null)
                        .snoozedUntil(null)
                        .build();
            }
        };
    }

    // SNOOZE 동작은 양수 분(minute) 입력이 필수다.
    private int resolveSnoozeMinutes(Integer snoozeMinutes) {
        if (snoozeMinutes == null || snoozeMinutes <= 0) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
        return snoozeMinutes;
    }

    /**
     * NOTI-03 알림 읽음 처리.
     */
    @Override
    @Transactional
    public NotificationReadUpdateResponseDto updateNotificationRead(
            Long userId,
            Long notificationId,
            NotificationReadUpdateRequestDto requestDto
    ) {
        if (!Boolean.TRUE.equals(requestDto.getIsRead())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }

        UserNotification notification = userNotificationRepository.findByIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        OffsetDateTime openedAt = OffsetDateTime.now();
        notification.markOpened(openedAt);

        return NotificationReadUpdateResponseDto.builder()
                .notificationId(notification.getId())
                .openedAt(openedAt)
                .build();
    }

    /**
     * NOTI-04 알림 삭제 처리.
     */
    @Override
    @Transactional
    public NotificationDeleteResponseDto deleteNotification(Long userId, Long notificationId) {
        UserNotification notification = userNotificationRepository.findByIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        userNotificationRepository.delete(notification);

        return NotificationDeleteResponseDto.builder()
                .notificationId(notificationId)
                .deletedAt(OffsetDateTime.now())
                .build();
    }

    private boolean isSendableTodo(Todo todo, List<TodoTimeCondition> conditions) {
        if (!TODO_STATUS_ACTIVE.equals(todo.getStatus())) return false;
        if (!todo.isAlertEnabled()) return false;

        OffsetDateTime now = OffsetDateTime.now();
        if (todo.getSnoozedUntil() != null && todo.getSnoozedUntil().isAfter(now)) return false;
        if (todo.getCooldownUntil() != null && todo.getCooldownUntil().isAfter(now)) return false;
        return matchesTimeConditions(conditions, now);
    }

    private boolean matchesTimeConditions(List<TodoTimeCondition> conditions, OffsetDateTime now) {
        if (conditions == null || conditions.isEmpty()) return true;
        for (TodoTimeCondition condition : conditions) {
            if (!matchesSingleCondition(condition, now)) return false;
        }
        return true;
    }

    private boolean matchesSingleCondition(TodoTimeCondition condition, OffsetDateTime now) {
        ConditionType type = condition.getConditionType();
        if (type == null) return true;

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
        if (start != null && target.isBefore(start)) return false;
        return end == null || !target.isAfter(end);
    }

    private boolean matchesWeekBitmask(DayOfWeek dayOfWeek, Short mask) {
        if (mask == null) return true;
        int bit = switch (dayOfWeek) {
            case MONDAY -> 1;
            case TUESDAY -> 2;
            case WEDNESDAY -> 4;
            case THURSDAY -> 8;
            case FRIDAY -> 16;
            case SATURDAY -> 32;
            case SUNDAY -> 64;
        };
        return (mask & bit) == bit;
    }

    private boolean isWithinTimeRange(LocalTime target, LocalTime start, LocalTime end) {
        if (start == null && end == null) return true;
        if (start != null && end != null && end.isBefore(start)) {
            return !target.isBefore(start) || !target.isAfter(end);
        }
        if (start != null && target.isBefore(start)) return false;
        return end == null || !target.isAfter(end);
    }

    private String buildTitle(Long placeId) {
        if (placeId == null) return TITLE_FALLBACK;
        return placeRepository.findById(placeId)
                .map(Place::getName)
                .filter(name -> !name.isBlank())
                .map(name -> name + TITLE_SUFFIX)
                .orElse(TITLE_FALLBACK);
    }

    private String buildBody(String todoContent) {
        return (todoContent == null || todoContent.isBlank()) ? BODY_FALLBACK : todoContent;
    }

    private UserNotification saveNotificationHistory(
            Long userId,
            Todo todo,
            Long candidatePlaceId,
            String title,
            String body,
            boolean sent
    ) {
        NotificationType notificationType = resolveNotificationType(todo);
        NotificationStatus status = sent ? NotificationStatus.SENT : NotificationStatus.FAILED;
        UserNotification notification = UserNotification.builder()
                .userId(userId)
                .todoId(todo.getId())
                .candidatePlaceId(candidatePlaceId)
                .notificationType(notificationType)
                .status(status)
                .title(title)
                .body(body)
                .build();
        return userNotificationRepository.save(notification);
    }

    private NotificationType resolveNotificationType(Todo todo) {
        String todoType = todo.getTodoType();
        if (todoType == null) return NotificationType.GENERIC;
        return switch (todoType) {
            case "SPECIFIC" -> NotificationType.SPECIFIC;
            case "GENERIC", "ALIAS", "GENERAL" -> NotificationType.GENERIC;
            default -> NotificationType.GENERIC;
        };
    }
}
