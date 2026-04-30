package com.timingnote.api.domain.notification.service;

import java.time.OffsetDateTime;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

public interface GeofenceSlotSseService {

    SseEmitter subscribe(Long userId);

    void notifySlotsUpdated(Long userId, OffsetDateTime lastCalculatedAt);
}

