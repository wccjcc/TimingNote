package com.timingnote.api.domain.notification.service;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Slf4j
@Service
public class GeofenceSlotSseServiceImpl implements GeofenceSlotSseService {

    private static final long SSE_TIMEOUT_MS = 30L * 60L * 1000L;
    private final Map<Long, List<SseEmitter>> emittersByUserId = new ConcurrentHashMap<>();

    @Override
    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        emittersByUserId.computeIfAbsent(userId, key -> new CopyOnWriteArrayList<>()).add(emitter);
        emitter.onCompletion(() -> removeEmitter(userId, emitter));
        emitter.onTimeout(() -> removeEmitter(userId, emitter));
        emitter.onError(ex -> removeEmitter(userId, emitter));

        try {
            emitter.send(SseEmitter.event()
                    .name("connected")
                    .data(Map.of("userId", userId, "connectedAt", OffsetDateTime.now().toString())));
        } catch (IOException ex) {
            removeEmitter(userId, emitter);
        }
        return emitter;
    }

    @Override
    public void notifySlotsUpdated(Long userId, OffsetDateTime lastCalculatedAt) {
        List<SseEmitter> emitters = emittersByUserId.get(userId);
        if (emitters == null || emitters.isEmpty()) {
            return;
        }
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event()
                        .name("slots-updated")
                        .data(Map.of(
                                "lastCalculatedAt", lastCalculatedAt == null ? null : lastCalculatedAt.toString()
                        )));
            } catch (IOException ex) {
                removeEmitter(userId, emitter);
                log.debug("Removed broken SSE emitter. userId={}", userId);
            }
        }
    }

    private void removeEmitter(Long userId, SseEmitter emitter) {
        List<SseEmitter> emitters = emittersByUserId.get(userId);
        if (emitters == null) {
            return;
        }
        emitters.remove(emitter);
        if (emitters.isEmpty()) {
            emittersByUserId.remove(userId);
        }
    }
}

