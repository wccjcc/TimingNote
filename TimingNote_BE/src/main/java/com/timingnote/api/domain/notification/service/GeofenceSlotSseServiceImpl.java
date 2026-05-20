package com.timingnote.api.domain.notification.service;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Slf4j
@Service
public class GeofenceSlotSseServiceImpl implements GeofenceSlotSseService {

    private static final long SSE_TIMEOUT_MS = 30L * 60L * 1000L;
    private static final long HEARTBEAT_INTERVAL_SEC = 20L;
    private final Map<Long, List<SseEmitter>> emittersByUserId = new ConcurrentHashMap<>();
    private final ScheduledExecutorService heartbeatExecutor = Executors.newSingleThreadScheduledExecutor();

    // SSE 연결 유지를 위해 주기적으로 heartbeat 이벤트를 전송한다.
    @PostConstruct
    void startHeartbeat() {
        heartbeatExecutor.scheduleAtFixedRate(
                this::broadcastHeartbeat,
                HEARTBEAT_INTERVAL_SEC,
                HEARTBEAT_INTERVAL_SEC,
                TimeUnit.SECONDS
        );
    }

    @PreDestroy
    void stopHeartbeat() {
        heartbeatExecutor.shutdownNow();
    }

    @Override
    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        emittersByUserId.computeIfAbsent(userId, key -> new CopyOnWriteArrayList<>()).add(emitter);
        emitter.onCompletion(() -> removeEmitter(userId, emitter, "completion"));
        emitter.onTimeout(() -> removeEmitter(userId, emitter, "timeout"));
        emitter.onError(ex -> removeEmitter(userId, emitter, "error"));

        try {
            emitter.send(SseEmitter.event()
                    .name("connected")
                    .data(Map.of("userId", userId, "connectedAt", OffsetDateTime.now().toString())));
        } catch (IOException | IllegalStateException ex) {
            removeEmitter(userId, emitter, "connect-send-failure");
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
            } catch (IOException | IllegalStateException ex) {
                removeEmitter(userId, emitter, "slots-updated-send-failure");
            }
        }
    }

    private void broadcastHeartbeat() {
        emittersByUserId.forEach((userId, emitters) -> {
            for (SseEmitter emitter : emitters) {
                try {
                    emitter.send(SseEmitter.event()
                            .name("ping")
                            .data(Map.of("ts", OffsetDateTime.now().toString())));
                } catch (IOException | IllegalStateException ex) {
                    removeEmitter(userId, emitter, "heartbeat-send-failure");
                }
            }
        });
    }

    private void removeEmitter(Long userId, SseEmitter emitter, String reason) {
        List<SseEmitter> emitters = emittersByUserId.get(userId);
        if (emitters == null) {
            return;
        }
        boolean removed = emitters.remove(emitter);
        if (emitters.isEmpty()) {
            emittersByUserId.remove(userId);
        }
        if (removed) {
            log.debug("Removed SSE emitter. userId={} reason={} remaining={}", userId, reason, emitters.size());
        }
    }
}
