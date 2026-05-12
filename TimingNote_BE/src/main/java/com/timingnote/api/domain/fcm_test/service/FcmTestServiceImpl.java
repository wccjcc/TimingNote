package com.timingnote.api.domain.fcm_test.service;

import com.timingnote.api.domain.fcm_test.dto.request.FcmGeofenceTestSendRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.infra.client.fcm.PushNotificationSender;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class FcmTestServiceImpl implements FcmTestService {

    private static final String PUSH_TYPE_GEOFENCE = "GEOFENCE";
    private static final String IOS_CATEGORY_GEOFENCE_TODO_ACTIONS = "GEOFENCE_TODO_ACTIONS";
    private static final String TITLE_SUFFIX = "에 도착했어요";
    private static final String TITLE_FALLBACK = "근처 도착 알림";
    private static final String BODY_FALLBACK = "가까운 장소 알림이 도착했어요.";

    private final PushNotificationSender pushNotificationSender;

    @Override
    public NotificationGeofenceSendResponseDto sendGeofenceStylePush(
            Long slotId,
            FcmGeofenceTestSendRequestDto requestDto
    ) {
        String title = buildTitle(requestDto.getPlaceName());
        String body = buildBody(requestDto.getTodoContent());

        Map<String, String> pushData = Map.of(
                "notificationId", String.valueOf(requestDto.getNotificationId()),
                "todoId", String.valueOf(requestDto.getTodoId()),
                "slotId", String.valueOf(slotId),
                "type", PUSH_TYPE_GEOFENCE
        );

        boolean sent = pushNotificationSender.send(
                requestDto.getToken().trim(),
                PUSH_TYPE_GEOFENCE,
                title,
                body,
                pushData,
                IOS_CATEGORY_GEOFENCE_TODO_ACTIONS
        );

        return NotificationGeofenceSendResponseDto.builder()
                .sent(sent)
                .reason(sent ? "SENT" : "FCM_SEND_FAILED")
                .build();
    }

    private String buildTitle(String placeName) {
        if (placeName == null || placeName.isBlank()) {
            return TITLE_FALLBACK;
        }
        return placeName.trim() + TITLE_SUFFIX;
    }

    private String buildBody(String todoContent) {
        if (todoContent == null || todoContent.isBlank()) {
            return BODY_FALLBACK;
        }
        return todoContent.trim();
    }
}
