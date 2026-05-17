package com.timingnote.api.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.notification.dto.request.NotificationActionRequestDto;
import com.timingnote.api.domain.notification.dto.request.NotificationReadUpdateRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationActionResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationDeleteResponseDto;
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
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import com.timingnote.api.infra.client.fcm.PushNotificationSender;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;
import org.mockito.stubbing.Answer;

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
    private PlaceRepository placeRepository;
    @Mock
    private UserPlaceRepository userPlaceRepository;
    @Mock
    private PushNotificationSender pushNotificationSender;
    @Mock
    private GeofenceRecalculateOutboxService geofenceRecalculateOutboxService;

    @InjectMocks
    private NotificationServiceImpl notificationService;

    private static final Long USER_ID = 1L;
    private static final Long SLOT_ID = 10L;
    private static final Long TODO_ID = 20L;

    private GeofenceSlot slot;
    private Todo todo;
    private Place place;

    @BeforeEach
    void setUp() {
        slot = new GeofenceSlot();
        ReflectionTestUtils.setField(slot, "id", SLOT_ID);
        ReflectionTestUtils.setField(slot, "userId", USER_ID);
        ReflectionTestUtils.setField(slot, "todoId", TODO_ID);
        ReflectionTestUtils.setField(slot, "placeId", 100L);

        todo = Todo.builder()
                .userId(USER_ID)
                .todoType("SPECIFIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content("buy milk")
                .alertEnabled(true)
                .build();
        ReflectionTestUtils.setField(todo, "id", TODO_ID);
        ReflectionTestUtils.setField(todo, "cooldownUntil", null);
        ReflectionTestUtils.setField(todo, "snoozedUntil", null);

        place = Place.builder()
                .externalPlaceId("ext-place")
                .name("스타벅스")
                .location(Place.toPoint(127.0, 37.0))
                .build();
        ReflectionTestUtils.setField(place, "id", 100L);

        lenient().when(placeRepository.findById(100L)).thenReturn(Optional.of(place));
        // save 결과 엔티티를 그대로 반환해 history null NPE를 방지한다.
        lenient().when(userNotificationRepository.save(any(UserNotification.class)))
                .thenAnswer((Answer<UserNotification>) invocation -> invocation.getArgument(0));
    }

    // Happy path: send + history + cooldown update
    @Test
    void send_success_when_allConditionsSatisfied() throws Exception {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of());
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isTrue();
        assertThat(result.getReason()).isEqualTo("SENT");
        assertThat(todo.getCooldownUntil()).isNotNull();
        verify(pushNotificationSender).send(eq("fcm-token"), eq("GEOFENCE"), eq("스타벅스근처에요"), eq("buy milk"), any(), any());

        ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
        verify(userNotificationRepository).save(captor.capture());
        assertThat(captor.getValue().getNotificationType()).isEqualTo(NotificationType.SPECIFIC);
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.SENT);
        assertThat(captor.getValue().getTitle()).isEqualTo("스타벅스근처에요");
        assertThat(captor.getValue().getBody()).isEqualTo("buy milk");
    }

    @Test
    void send_success_usesAliasNameInTitle_whenTodoTypeAlias() throws Exception {
        ReflectionTestUtils.setField(todo, "todoType", "ALIAS");
        UserPlace userPlace = UserPlace.builder()
                .aliasName("회사")
                .place(place)
                .build();

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of());
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(userPlaceRepository.findFirstByUser_IdAndPlace_IdOrderByIdAsc(USER_ID, 100L))
                .thenReturn(Optional.of(userPlace));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

        assertThat(result.isSent()).isTrue();
        verify(pushNotificationSender).send(eq("fcm-token"), eq("GEOFENCE"), eq("회사근처에요"), eq("buy milk"), any(), any());
        verify(placeRepository, never()).findById(100L);
    }

    // slot not found => NOT_FOUND
    @Test
    void send_fail404_when_slotNotFound() {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationService.sendGeofenceNotification(USER_ID, SLOT_ID))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    // owner mismatch => NOT_FOUND
    @Test
    void send_fail404_when_slotOwnerMismatch() {
        ReflectionTestUtils.setField(slot, "userId", USER_ID + 1);
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));

        assertThatThrownBy(() -> notificationService.sendGeofenceNotification(USER_ID, SLOT_ID))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    // status != ACTIVE
    @Test
    void send_false_when_todoStatusNotActive() {
        ReflectionTestUtils.setField(todo, "status", "DONE");
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
        verify(userNotificationRepository, never()).save(any());
    }

    // alertEnabled=false
    @Test
    void send_false_when_alertDisabled() {
        ReflectionTestUtils.setField(todo, "alertEnabled", false);
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // snooze active
    @Test
    void send_false_when_snoozed() {
        ReflectionTestUtils.setField(todo, "snoozedUntil", OffsetDateTime.now().plusMinutes(10));
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // cooldown active
    @Test
    void send_false_when_cooldown() {
        ReflectionTestUtils.setField(todo, "cooldownUntil", OffsetDateTime.now().plusMinutes(10));
        mockBaseForTodoValidation();

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // WEEK mask mismatch
    @Test
    void send_false_when_weekMaskDoesNotMatchToday() {
        DayOfWeek today = OffsetDateTime.now().getDayOfWeek();
        short todayBit = dayBit(today);
        short maskWithoutToday = (short) (127 - todayBit);

        TodoTimeCondition weekCondition = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", maskWithoutToday);
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(weekCondition));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // WEEK mask match
    @Test
    void send_true_when_weekMaskMatchesToday() throws Exception {
        short todayMask = dayBit(OffsetDateTime.now().getDayOfWeek());
        TodoTimeCondition weekCondition = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", todayMask);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(weekCondition));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // TIME_RANGE out
    @Test
    void send_false_when_timeRangeNotMatch() {
        TodoTimeCondition timeRange = condition(ConditionType.TIME_RANGE);
        ReflectionTestUtils.setField(timeRange, "startTime", LocalTime.of(1, 0));
        ReflectionTestUtils.setField(timeRange, "endTime", LocalTime.of(1, 30));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(timeRange));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // DATE_RANGE out
    @Test
    void send_false_when_dateRangeNotMatch() {
        TodoTimeCondition dateRange = condition(ConditionType.DATE_RANGE);
        ReflectionTestUtils.setField(dateRange, "startDate", LocalDate.now().plusDays(1));
        ReflectionTestUtils.setField(dateRange, "endDate", LocalDate.now().plusDays(2));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(dateRange));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    // DATE boundary include
    @Test
    void send_true_when_dateConditionStartDateIsToday() throws Exception {
        TodoTimeCondition date = condition(ConditionType.DATE);
        ReflectionTestUtils.setField(date, "startDate", LocalDate.now());

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(date));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // DATE future start
    @Test
    void send_false_when_dateConditionStartDateIsTomorrow() {
        TodoTimeCondition date = condition(ConditionType.DATE);
        ReflectionTestUtils.setField(date, "startDate", LocalDate.now().plusDays(1));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(date));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    @Test
    void send_false_when_datetimeConditionIsFuture() {
        TodoTimeCondition dateTime = condition(ConditionType.DATETIME);
        ReflectionTestUtils.setField(dateTime, "startDate", LocalDate.now().plusDays(1));
        ReflectionTestUtils.setField(dateTime, "startTime", LocalTime.of(18, 0));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(dateTime));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    @Test
    void send_true_when_datetimeConditionIsPast() throws Exception {
        LocalDateTime base = LocalDateTime.now().minusMinutes(1);
        TodoTimeCondition dateTime = condition(ConditionType.DATETIME);
        ReflectionTestUtils.setField(dateTime, "startDate", base.toLocalDate());
        ReflectionTestUtils.setField(dateTime, "startTime", base.toLocalTime().withNano(0));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(dateTime));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    void send_false_when_weekMaskMatchesButTimeWindowNotMatch() {
        short todayMask = dayBit(OffsetDateTime.now().getDayOfWeek());
        TodoTimeCondition weekCondition = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", todayMask);
        ReflectionTestUtils.setField(weekCondition, "startTime", LocalTime.of(1, 0));
        ReflectionTestUtils.setField(weekCondition, "endTime", LocalTime.of(1, 30));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(weekCondition));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    @Test
    void send_true_when_weekMaskAndTimeWindowBothMatch() throws Exception {
        short todayMask = dayBit(OffsetDateTime.now().getDayOfWeek());
        LocalTime now = LocalTime.now();
        TodoTimeCondition weekCondition = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(weekCondition, "daysOfWeek", todayMask);
        ReflectionTestUtils.setField(weekCondition, "startTime", now.minusMinutes(3));
        ReflectionTestUtils.setField(weekCondition, "endTime", now.plusMinutes(3));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(weekCondition));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // DATE_RANGE inclusive boundaries
    @Test
    void send_true_when_dateRangeBoundaryInclusive() throws Exception {
        TodoTimeCondition dateRange = condition(ConditionType.DATE_RANGE);
        ReflectionTestUtils.setField(dateRange, "startDate", LocalDate.now());
        ReflectionTestUtils.setField(dateRange, "endDate", LocalDate.now());

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(dateRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    @Test
    void send_false_when_dateConditionTimeWindowNotMatch() {
        TodoTimeCondition date = condition(ConditionType.DATE);
        ReflectionTestUtils.setField(date, "startDate", LocalDate.now());
        ReflectionTestUtils.setField(date, "startTime", LocalTime.of(1, 0));
        ReflectionTestUtils.setField(date, "endTime", LocalTime.of(1, 30));
        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(date));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
    }

    @Test
    void send_true_when_dateRangeAndTimeWindowMatch() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition dateRange = condition(ConditionType.DATE_RANGE);
        ReflectionTestUtils.setField(dateRange, "startDate", LocalDate.now().minusDays(1));
        ReflectionTestUtils.setField(dateRange, "endDate", LocalDate.now().plusDays(1));
        ReflectionTestUtils.setField(dateRange, "startTime", now.minusMinutes(3));
        ReflectionTestUtils.setField(dateRange, "endTime", now.plusMinutes(3));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(dateRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // WEEK 127 daily
    @Test
    void send_true_when_weekMaskEveryday127() throws Exception {
        TodoTimeCondition week = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 127);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(week));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // WEEK 31 weekdays only
    @Test
    void send_weekMask31_weekdayOnly() throws Exception {
        TodoTimeCondition week = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 31);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(week));
        boolean weekday = OffsetDateTime.now().getDayOfWeek().getValue() <= 5;
        if (weekday) {
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);
        }

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isEqualTo(weekday);
    }

    // WEEK 96 weekend only
    @Test
    void send_weekMask96_weekendOnly() throws Exception {
        TodoTimeCondition week = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(week, "daysOfWeek", (short) 96);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(week));
        boolean weekend = OffsetDateTime.now().getDayOfWeek().getValue() >= 6;
        if (weekend) {
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);
        }

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isEqualTo(weekend);
    }

    // WEEK mixed mask contains today
    @Test
    void send_true_when_weekMaskContainsToday_example3Logic() throws Exception {
        short today = dayBit(OffsetDateTime.now().getDayOfWeek());
        short mask = (short) (today | 2);
        TodoTimeCondition week = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(week, "daysOfWeek", mask);

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(week));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // TIME_RANGE start boundary
    @Test
    void send_true_when_timeRangeStartBoundaryInclusive() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition(ConditionType.TIME_RANGE);
        ReflectionTestUtils.setField(timeRange, "startTime", now.minusSeconds(1));
        ReflectionTestUtils.setField(timeRange, "endTime", now.plusMinutes(5));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // TIME_RANGE end boundary
    @Test
    void send_true_when_timeRangeEndBoundaryInclusive() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition(ConditionType.TIME_RANGE);
        ReflectionTestUtils.setField(timeRange, "startTime", now.minusMinutes(5));
        ReflectionTestUtils.setField(timeRange, "endTime", now.plusSeconds(1));

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // TIME_RANGE overnight
    @Test
    void send_true_when_timeRangeAcrossMidnightMatchesNow() throws Exception {
        LocalTime now = LocalTime.now();
        TodoTimeCondition timeRange = condition(ConditionType.TIME_RANGE);

        if (now.isAfter(LocalTime.of(22, 0)) || now.isBefore(LocalTime.of(2, 0))) {
            ReflectionTestUtils.setField(timeRange, "startTime", LocalTime.of(22, 0));
            ReflectionTestUtils.setField(timeRange, "endTime", LocalTime.of(2, 0));
        } else {
            ReflectionTestUtils.setField(timeRange, "startTime", now.minusMinutes(2));
            ReflectionTestUtils.setField(timeRange, "endTime", now.plusMinutes(2));
        }

        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(timeRange));
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isTrue();
    }

    // AND across multiple conditions
    @Test
    void send_false_when_multipleConditionsAndOneFails() {
        TodoTimeCondition okWeek = condition(ConditionType.WEEK);
        ReflectionTestUtils.setField(okWeek, "daysOfWeek", (short) 127);
        TodoTimeCondition failDate = condition(ConditionType.DATE);
        ReflectionTestUtils.setField(failDate, "startDate", LocalDate.now().plusDays(1));

        mockBaseForTodoValidation();
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of(okWeek, failDate));

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("TODO_NOT_SENDABLE");
    }

    // token missing
    @Test
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

    // FCM exception
    @Test
    void send_false_when_fcmSendThrowsException() throws Exception {
        mockBaseForTodoValidation();
        when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
        when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(false);

        NotificationGeofenceSendResponseDto result = notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);
        assertThat(result.isSent()).isFalse();
        assertThat(result.getReason()).isEqualTo("FCM_SEND_FAILED");
        ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
        verify(userNotificationRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(NotificationStatus.FAILED);
    }

    // notification type mapping
    @Test
    void save_genericNotificationType_when_todoTypeGenericAliasGeneral() throws Exception {
        for (String todoType : List.of("GENERIC", "ALIAS", "GENERAL")) {
            clearInvocations(userNotificationRepository);

            Todo caseTodo = Todo.builder()
                    .userId(USER_ID)
                    .todoType(todoType)
                    .status("ACTIVE")
                    .structureStatus("READY")
                    .content("test")
                    .alertEnabled(true)
                    .build();
            ReflectionTestUtils.setField(caseTodo, "id", TODO_ID);

            when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
            when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(caseTodo));
            when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of());
            when(userFcmTokenRepository.findByUserId(USER_ID)).thenReturn(Optional.of(activeToken(USER_ID, "fcm-token")));
            when(pushNotificationSender.send(any(), any(), any(), any(), any(), any())).thenReturn(true);

            notificationService.sendGeofenceNotification(USER_ID, SLOT_ID);

            ArgumentCaptor<UserNotification> captor = ArgumentCaptor.forClass(UserNotification.class);
            verify(userNotificationRepository).save(captor.capture());
            assertThat(captor.getValue().getNotificationType()).isEqualTo(NotificationType.GENERIC);
        }
    }

    // NOTI-01: userId 기준 페이지 조회 결과를 응답 DTO로 매핑한다.
    @Test
    void get_history_success_withoutTodoFilter() {
        UserNotification n1 = notification(101L, USER_ID, TODO_ID, NotificationStatus.SENT);
        UserNotification n2 = notification(102L, USER_ID, TODO_ID, NotificationStatus.OPENED);
        Page<UserNotification> page = new PageImpl<>(List.of(n1, n2), PageRequest.of(0, 20), 2);
        when(userNotificationRepository.findByUserId(eq(USER_ID), any())).thenReturn(page);

        NotificationHistoryResponseDto result = notificationService.getNotificationHistory(USER_ID, null, 0, 20);

        assertThat(result.getContent()).hasSize(2);
        assertThat(result.getTotalElements()).isEqualTo(2);
        assertThat(result.getPage()).isEqualTo(0);
        assertThat(result.getSize()).isEqualTo(20);
        verify(userNotificationRepository).findByUserId(eq(USER_ID), any());
    }

    // NOTI-01: todoId 필터가 있을 때 필터 메서드가 호출된다.
    @Test
    void get_history_success_withTodoFilter() {
        Page<UserNotification> page = new PageImpl<>(List.of(notification(101L, USER_ID, TODO_ID, NotificationStatus.SENT)));
        when(userNotificationRepository.findByUserIdAndTodoId(eq(USER_ID), eq(TODO_ID), any())).thenReturn(page);

        NotificationHistoryResponseDto result = notificationService.getNotificationHistory(USER_ID, TODO_ID, 0, 20);

        assertThat(result.getContent()).hasSize(1);
        verify(userNotificationRepository).findByUserIdAndTodoId(eq(USER_ID), eq(TODO_ID), any());
    }

    // NOTI-01: page/size 검증 실패 시 VALIDATION_ERROR를 던진다.
    @Test
    void get_history_fail_validation_when_pageOrSizeInvalid() {
        assertThatThrownBy(() -> notificationService.getNotificationHistory(USER_ID, null, -1, 20))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);

        assertThatThrownBy(() -> notificationService.getNotificationHistory(USER_ID, null, 0, 0))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);
    }

    // NOTI-02: OPEN 액션은 알림을 OPENED로 바꾸고 openedAt을 기록한다.
    @Test
    void action_open_success() {
        UserNotification notification = notification(201L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(201L, USER_ID)).thenReturn(Optional.of(notification));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));

        NotificationActionResponseDto result = notificationService.applyNotificationAction(
                USER_ID, 201L, actionRequest("OPEN", null)
        );

        assertThat(result.getActionType()).isEqualTo("OPEN");
        assertThat(notification.getStatus()).isEqualTo(NotificationStatus.OPENED);
        assertThat(notification.getOpenedAt()).isNotNull();
    }

    // NOTI-02: COMPLETE 액션은 Todo를 DONE으로 변경한다.
    @Test
    void action_complete_success() {
        UserNotification notification = notification(202L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(202L, USER_ID)).thenReturn(Optional.of(notification));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));

        NotificationActionResponseDto result = notificationService.applyNotificationAction(
                USER_ID, 202L, actionRequest("COMPLETE", null)
        );

        assertThat(result.getActionType()).isEqualTo("COMPLETE");
        assertThat(result.getTodoStatus()).isEqualTo("DONE");
        assertThat(todo.getStatus()).isEqualTo("DONE");
    }

    // NOTI-02: SNOOZE 액션은 snoozedUntil을 설정한다.
    @Test
    void action_snooze_success() {
        UserNotification notification = notification(203L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(203L, USER_ID)).thenReturn(Optional.of(notification));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));

        NotificationActionResponseDto result = notificationService.applyNotificationAction(
                USER_ID, 203L, actionRequest("SNOOZE", 60)
        );

        assertThat(result.getActionType()).isEqualTo("SNOOZE");
        assertThat(result.getSnoozedUntil()).isNotNull();
        assertThat(todo.getSnoozedUntil()).isNotNull();
    }

    // NOTI-02: SNOOZE에서 분(minute)이 비정상이면 VALIDATION_ERROR다.
    @Test
    void action_snooze_fail_validation_when_minutesInvalid() {
        UserNotification notification = notification(204L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(204L, USER_ID)).thenReturn(Optional.of(notification));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));

        assertThatThrownBy(() -> notificationService.applyNotificationAction(
                USER_ID, 204L, actionRequest("SNOOZE", null)))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);
    }

    // NOTI-02: 알림 또는 Todo가 없으면 NOT_FOUND를 반환한다.
    @Test
    void action_fail_notFound_when_notificationOrTodoMissing() {
        when(userNotificationRepository.findByIdAndUserId(205L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationService.applyNotificationAction(
                USER_ID, 205L, actionRequest("OPEN", null)))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    // NOTI-03: isRead=true면 읽음 처리(openedAt 갱신)된다.
    @Test
    void read_update_success() {
        UserNotification notification = notification(301L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(301L, USER_ID)).thenReturn(Optional.of(notification));

        NotificationReadUpdateResponseDto result = notificationService.updateNotificationRead(
                USER_ID, 301L, readRequest(true)
        );

        assertThat(result.getNotificationId()).isEqualTo(301L);
        assertThat(result.getOpenedAt()).isNotNull();
        assertThat(notification.getStatus()).isEqualTo(NotificationStatus.OPENED);
    }

    // NOTI-03: isRead=false면 VALIDATION_ERROR다.
    @Test
    void read_update_fail_validation_when_isReadFalse() {
        assertThatThrownBy(() -> notificationService.updateNotificationRead(USER_ID, 301L, readRequest(false)))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.VALIDATION_ERROR);
    }

    // NOTI-03: 대상 알림이 없으면 NOT_FOUND다.
    @Test
    void read_update_fail_notFound() {
        when(userNotificationRepository.findByIdAndUserId(302L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationService.updateNotificationRead(USER_ID, 302L, readRequest(true)))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    // NOTI-04: 알림 삭제 성공 시 delete 호출 및 응답값을 확인한다.
    @Test
    void delete_success() {
        UserNotification notification = notification(401L, USER_ID, TODO_ID, NotificationStatus.SENT);
        when(userNotificationRepository.findByIdAndUserId(401L, USER_ID)).thenReturn(Optional.of(notification));

        NotificationDeleteResponseDto result = notificationService.deleteNotification(USER_ID, 401L);

        assertThat(result.getNotificationId()).isEqualTo(401L);
        assertThat(result.getDeletedAt()).isNotNull();
        verify(userNotificationRepository).delete(notification);
    }

    // NOTI-04: 대상 알림이 없으면 NOT_FOUND다.
    @Test
    void delete_fail_notFound() {
        when(userNotificationRepository.findByIdAndUserId(402L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> notificationService.deleteNotification(USER_ID, 402L))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    private void mockBaseForTodoValidation() {
        when(geofenceSlotRepository.findById(SLOT_ID)).thenReturn(Optional.of(slot));
        when(todoRepository.findById(TODO_ID)).thenReturn(Optional.of(todo));
        when(todoTimeConditionRepository.findAllByTodo_Id(TODO_ID)).thenReturn(List.of());
    }

    private UserFcmToken activeToken(Long userId, String token) {
        return new UserFcmToken(userId, token, "IOS", true);
    }

    private TodoTimeCondition condition(ConditionType type) {
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

    private UserNotification notification(Long id, Long userId, Long todoId, NotificationStatus status) {
        UserNotification notification = UserNotification.builder()
                .userId(userId)
                .todoId(todoId)
                .notificationType(NotificationType.GENERIC)
                .status(status)
                .title("test")
                .body("test-body")
                .build();
        ReflectionTestUtils.setField(notification, "id", id);
        ReflectionTestUtils.setField(notification, "createdAt", OffsetDateTime.now());
        return notification;
    }

    private NotificationActionRequestDto actionRequest(String actionType, Integer snoozeMinutes) {
        NotificationActionRequestDto requestDto = new NotificationActionRequestDto();
        ReflectionTestUtils.setField(requestDto, "actionType", Enum.valueOf(
                com.timingnote.api.domain.notification.dto.request.NotificationActionType.class, actionType
        ));
        ReflectionTestUtils.setField(requestDto, "snoozeMinutes", snoozeMinutes);
        return requestDto;
    }

    private NotificationReadUpdateRequestDto readRequest(boolean isRead) {
        NotificationReadUpdateRequestDto requestDto = new NotificationReadUpdateRequestDto();
        ReflectionTestUtils.setField(requestDto, "isRead", isRead);
        return requestDto;
    }
}
