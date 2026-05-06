package com.timingnote.api.domain.notification.consumer;

import com.timingnote.api.domain.notification.dto.request.GeofenceSlotRecalculateEvent;
import com.timingnote.api.domain.notification.service.GeofenceSlotManager;
import com.timingnote.api.domain.place.service.GenericCandidateRefreshService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class GeofenceSlotRecalculateConsumer {

    private final GenericCandidateRefreshService genericCandidateRefreshService;
    private final GeofenceSlotManager geofenceSlotManager;

    @RabbitListener(
            queues = "${app.rabbitmq.geofence-slot-recalculate-queue:geofence.slot.recalculate}",
            containerFactory = "geofenceRabbitListenerContainerFactory"
    )
    public void consume(GeofenceSlotRecalculateEvent event) {
        log.info("Consume geofence slot recalculate event. userId={}", event.userId());
        genericCandidateRefreshService.refresh(event.userId(), event.latitude(), event.longitude());
        geofenceSlotManager.recalculateSlots(event);
    }
}
