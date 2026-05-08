package com.timingnote.api.infra.client.fcm;

import java.util.Map;

public interface PushNotificationSender {

    boolean send(
            String token,
            String type,
            String title,
            String body,
            Map<String, String> data,
            String iosCategory
    );
}
