package com.timingnote.api.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
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
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class NotificationServiceImplTest {

    @Mock
    private GeofenceSlotRepository geofenceSlotRepository;
    @Mock
    private TodoRepository todoRepository;
    @Mock
    private TodoTimeConditionRepository todoTimeConditionRepository;
    @Mock
    private UserFcmTokenRepository userFcmTokenRepository;
    @Mock
    private UserNotificationRepository userNotificationRepository;
    @Mock
    private FirebaseMessaging firebaseMessaging;

    @InjectMocks
    private NotificationServiceImpl notificationService;

    private static final Long USER_ID = 1L;
    private static final Long SLOT_ID = 10L;
    private static final Long TODO_ID = 20L;

    private GeofenceSlot slot;
    private Todo todo;

    @BeforeEach
    void setUp() {
        slot = new GeofenceSlot();
        ReflectionTestUtils.setField(slot, "id", SLOT_ID);
        ReflectionTestUtils.setField(slot, "userId", USER_ID);
        ReflectionTestUtils.setField(slot, "todoId", TODO_ID);

        todo = Todo.builder()
                .userId(USER_ID)
                .todoType("SPECIFIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content("우유 사기")
                .alertEnabled(true)
                .build();
        ReflectionTestUtils.setField(todo, "id", TODO_ID);
        ReflectionTestUtils.setField(todo, "cooldownUntil", null);
        ReflectionTestUtils.setField(todo, "snoozedUntil", null);
    }

    @Test
    // 정상 시나리오: 모든 조건 만족 시 알림 전송 성공 + SENT 이력 저장 + cooldown 설정
    void send_success_when_allConditionsSatisfied() throws Exception {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of());
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isTrue();
        assertThat(result.getReason()).isEqualTo("SENT");
        assertThat(todo.getCooldownUntil()).isNotNull();

        ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
        verify(userNotificationRepository).save(captor.capture());
        assertThat(captor.getValue().getNotificationType()).isEqualTo(NotificationType.SPECIFIC);
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.SENT);
    }

    @Test
    // 예외 시나리오: geofence slot이 없으면 NOT_FOUND 예외
    void send_fail404_when_slotNotFound() {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationService.sendGeofenceNotification(USER_ID, SLOT_ID))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    @Test
    // 예외 시나리오: slot 소유자와 요청 userId가 다르면 NOT_FOUND 예외
    void send_fail404_when_slotOwnerMismatch() {
        ReflectionTestUtils.setField(slot, "userId", USER_ID + 1);
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));

        assertThatThrownBy(() -> notificationService.sendGeofenceNotification(USER_ID, SLOT_ID))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    @Test
    // 조건 실패: todo.status가 ACTIVE가 아니면 발송하지 않음
    void send_false_when_todoStatusNotActive() {
        ReflectionTestUtils.setField(todo, "status", "DONE");
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
        verify(userNotificationRepository, never()).save(any());
    }

    @Test
    // 조건 실패: alertEnabled=false이면 발송하지 않음
    void send_false_when_alertDisabled() {
        ReflectionTestUtils.setField(todo, "alertEnabled", false);
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // 조건 실패: snoozedUntil이 미래면 발송하지 않음
    void send_false_when_snoozed() {
        ReflectionTestUtils.setField(todo, "snoozedUntil", OffsetDateTime.now().plusMinutes(10));
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // 조건 실패: cooldownUntil이 미래면 발송하지 않음
    void send_false_when_cooldown() {
        ReflectionTestUtils.setField(todo, "cooldownUntil", OffsetDateTime.now().plusMinutes(10));
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // WEEK 비트마스크 실패: 오늘 요일 비트가 마스크에 없으면 발송하지 않음
    void send_false_when_weekMaskDoesNotMatchToday() {
        DayOfWeek today = OffsetDateTime.now().getDayOfWeek();
        short todayBit = dayBit(today);
        short maskWithoutToday = (short) (127 - todayBit);

        TodoTimeCondition weekCondition = condition("WEEK");
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", maskWithoutToday);
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(weekCondition));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // WEEK 비트마스크 성공: 오늘 요일 비트가 마스크에 있으면 발송
    void send_true_when_weekMaskMatchesToday() throws Exception {
        short todayMask = dayBit(OffsetDateTime.now().getDayOfWeek());
        TodoTimeCondition weekCondition = condition("WEEK");
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", todayMask);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(weekCondition));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isTrue();
    }

    @Test
    // TIME_RANGE 실패: 현재 시간이 범위 밖이면 발송하지 않음
    void send_false_when_timeRangeNotMatch() {
        TodoTimeCondition timeRange = condition("TIME_RANGE");
        ReflectionTestUtils.setField(timeRange, "startTime", LocalTime.of(1, 0));
        ReflectionTestUtils.setField(timeRange, "endTime", LocalTime.of(1, 30));

        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(timeRange));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // DATE_RANGE 실패: 현재 날짜가 범위 밖이면 발송하지 않음
    void send_false_when_dateRangeNotMatch() {
        TodoTimeCondition dateRange = condition("DATE_RANGE");
        ReflectionTestUtils.setField(dateRange, "startDate", LocalDate.now().plusDays(1));
        ReflectionTestUtils.setField(dateRange, "endDate", LocalDate.now().plusDays(2));

        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(dateRange));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // DATE 경계값 성공: startDate=오늘이면(포함) 발송 가능
    void send_true_when_dateConditionStartDateIsToday() throws Exception {
        TodoTimeCondition date = condition("DATE");
        ReflectionTestUtils.setField(date, "startDate", LocalDate.now());

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(date));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // DATE 경계값 실패: startDate=내일이면 아직 발송 불가
    void send_false_when_dateConditionStartDateIsTomorrow() {
        TodoTimeCondition date = condition("DATE");
        ReflectionTestUtils.setField(date, "startDate", LocalDate.now().plusDays(1));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(date));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    @Test
    // DATE_RANGE 경계값 성공: start/end가 오늘과 같아도(포함) 발송 가능
    void send_true_when_dateRangeBoundaryInclusive() throws Exception {
        TodoTimeCondition dateRange = condition("DATE_RANGE");
        ReflectionTestUtils.setField(dateRange, "startDate", LocalDate.now());
        ReflectionTestUtils.setField(dateRange, "endDate", LocalDate.now());

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(dateRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // WEEK 마스크 127(매일): 어떤 요일이든 발송 가능
    void send_true_when_weekMaskEveryday127() throws Exception {
        TodoTimeCondition week = condition("WEEK");
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 127);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(week));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // WEEK 마스크 31(월~금): 평일만 true, 주말 false 검증
    void send_weekMask31_weekdayOnly() throws Exception {
        TodoTimeCondition week = condition("WEEK");
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 31);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(week));
        boolean weekday = OffsetDateTime.now().getDayOfWeek().getValue() <= 5;
        if (weekday) {
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(firebaseMessaging.send(any())).thenReturn("msg-id");
        }
        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isEqualTo(weekday);
    }

    @Test
    // WEEK 마스크 96(토/일): 주말만 true, 평일 false 검증
    void send_weekMask96_weekendOnly() throws Exception {
        TodoTimeCondition week = condition("WEEK");
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 96);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(week));
        boolean weekend = OffsetDateTime.now().getDayOfWeek().getValue() >= 6;
        if (weekend) {
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(firebaseMessaging.send(any())).thenReturn("msg-id");
        }
        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isEqualTo(weekend);
    }

    @Test
    // WEEK 마스크 조합값(예: 3) 로직: 오늘 비트가 포함되면 발송 가능
    void send_true_when_weekMaskContainsToday_example3Logic() throws Exception {
        short today = dayBit(OffsetDateTime.now().getDayOfWeek());
        short mask = (short) (today | 2); // 오늘 + 화요일(bit2) 예시 결합
        TodoTimeCondition week = condition("WEEK");
        ReflectionTestUtils.setField(week, "daysOfWeek", mask);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(week));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // TIME_RANGE 경계값 성공: 시작 시각 경계(포함) 부근
    void send_true_when_timeRangeStartBoundaryInclusive() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition("TIME_RANGE");
        ReflectionTestUtils.setField(timeRange, "startTime", now.minusSeconds(1));
        ReflectionTestUtils.setField(timeRange, "endTime", now.plusMinutes(5));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // TIME_RANGE 경계값 성공: 종료 시각 경계(포함) 부근
    void send_true_when_timeRangeEndBoundaryInclusive() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition("TIME_RANGE");
        ReflectionTestUtils.setField(timeRange, "startTime", now.minusMinutes(5));
        ReflectionTestUtils.setField(timeRange, "endTime", now.plusSeconds(1));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // TIME_RANGE 자정 넘김 성공: 22:00~02:00 같은 overnight 범위 처리 검증
    void send_true_when_timeRangeAcrossMidnightMatchesNow() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition("TIME_RANGE");

        if (now.isAfter(LocalTime.of(22, 0)) || now.isBefore(LocalTime.of(2, 0))) {
            ReflectionTestUtils.setField(timeRange, "startTime", LocalTime.of(22, 0));
            ReflectionTestUtils.setField(timeRange, "endTime", LocalTime.of(2, 0));
        } else {
            ReflectionTestUtils.setField(timeRange, "startTime", now.minusMinutes(2));
            ReflectionTestUtils.setField(timeRange, "endTime", now.plusMinutes(2));
        }

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenReturn("msg-id");

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    // 다중 조건 AND 검증: 여러 조건 중 하나라도 실패하면 전체 미발송
    void send_false_when_multipleConditionsAndOneFails() {
        TodoTimeCondition okWeek = condition("WEEK");
        ReflectionTestUtils.setField(okWeek, "daysOfWeek", (short) 127);

        TodoTimeCondition failDate = condition("DATE");
        ReflectionTestUtils.setField(failDate, "startDate", LocalDate.now().plusDays(1));

        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of(okWeek, failDate));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    @Test
    // 토큰 조건 실패: 활성 FCM 토큰이 없으면 미발송 + FAILED 이력 저장
    void send_false_when_noActiveFcmToken() {
        mockBaseForTodoValidation();
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("FCM_TOKEN_NOT_AVAILABLE");
        ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
        verify(userNotificationRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.FAILED);
    }

    @Test
    // 전송 실패 처리: FCM 예외 발생 시 미발송 + FAILED 이력 저장
    void send_false_when_fcmSendThrowsException() throws Exception {
        mockBaseForTodoValidation();
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(firebaseMessaging.send(any())).thenThrow(Mockito.mock(FirebaseMessagingException.class));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("FCM_SEND_FAILED");
        ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
        verify(userNotificationRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.FAILED);
    }

    @Test
    // notification_type 매핑: todoType이 GENERIC/ALIAS/GENERAL이면 GENERIC 저장
    void save_genericNotificationType_when_todoTypeGenericAliasGeneral() throws Exception {
        for (String todoType : List.of("GENERIC", "ALIAS", "GENERAL")) {
            clearInvocations(userNotificationRepository);

            Todo caseTodo = Todo.builder()
                    .userId(USER_ID)
                    .todoType(todoType)
                    .status("ACTIVE")
                    .structureStatus("READY")
                    .content("테스트")
                    .alertEnabled(true)
                    .build();
            ReflectionTestUtils.setField(caseTodo, "id", TODO_ID);

            when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
            when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(caseTodo));
            when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of());
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(firebaseMessaging.send(any())).thenReturn("msg-id");

            notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

            ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
            verify(userNotificationRepository).save(captor.capture());
            assertThat(captor.getValue().getNotificationType()).isEqualTo(NotificationType.GENERIC);
        }
    }

    private void mockBaseForTodoValidation() {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findByTodoId(TODO_ID)).thenReturn(List.of());
    }

    private UserFcmToken activeToken(Long userId, String token) {
        return new UserFcmToken(userId, token, "IOS", true);
    }

    private TodoTimeCondition condition(String type) {
        TodoTimeCondition condition = TodoTimeCondition.builder().build();
        ReflectionTestUtils.setField(condition, "conditionType", type);
        return condition;
    }

    private short dayBit(DayOfWeek dayOfWeek) {
        return switch (dayOfWeek) {
            case MONDAY -> 1;
            case TUESDAY -> 2;
            case WEDNESDAY -> 4;
            case THURSDAY -> 8;
            case FRIDAY -> 16;
            case SATURDAY -> 32;
            case SUNDAY -> 64;
        };
    }
}
