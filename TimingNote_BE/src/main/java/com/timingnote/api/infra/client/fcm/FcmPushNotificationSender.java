package com.timingnote.api.infra.client.fcm;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class FcmPushNotificationSender implements PushNotificationSender {

    private final FirebaseMessaging firebaseMessaging;

    @Override
    public boolean send(String token, String type, String title, String body) {
        Message message = Message.builder()
                .setToken(token)
                // iOS에서는 notification payload가 있어야 시스템 알림 표시가 안정적이다.
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                .putData("type", type)
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
}
