package com.timingnote.api.infra.client.fcm;

import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class FcmPushNotificationSender implements PushNotificationSender {

    private final FirebaseMessaging firebaseMessaging;

    @Override
    public boolean send(
            String token,
            String type,
            String title,
            String body,
            Map<String, String> data,
            String iosCategory
    ) {
        Message.Builder builder = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                .putData("type", type)
                .putData("title", title)
                .putData("body", body);

        if (data != null && !data.isEmpty()) {
            builder.putAllData(data);
        }

        // iOS 액션 버튼 노출을 위해 APNs category를 명시합니다.
        // 클라이언트 AppDelegate의 등록 category 식별자와 동일해야 합니다.
        if (iosCategory != null && !iosCategory.isBlank()) {
            builder.setApnsConfig(
                    ApnsConfig.builder()
                            .setAps(Aps.builder().setCategory(iosCategory).build())
                            .build()
            );
        }

        Message message = builder.build();

        try {
            firebaseMessaging.send(message);
            return true;
        } catch (FirebaseMessagingException e) {
            log.warn("FCM send failed. tokenUserMessage={}", e.getMessage());
            return false;
        }
    }
}
