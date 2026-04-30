package com.timingnote.api.infra.client.fcm;

public interface PushNotificationSender {

    boolean send(String token, String type, String title, String body);
}
