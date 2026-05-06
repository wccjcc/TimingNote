package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceSlotRecalculateEvent;
import com.timingnote.api.domain.notification.entity.GeofenceOutboxStatus;
import com.timingnote.api.domain.notification.entity.GeofenceRecalculateOutbox;
import com.timingnote.api.domain.notification.repository.GeofenceRecalculateOutboxRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeofenceRecalculateOutboxServiceImpl implements GeofenceRecalculateOutboxService {

    private final GeofenceRecalculateOutboxRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;

    @Value("${app.rabbitmq.geofence-slot-exchange:geofence.slot.exchange}")
    private String exchange;

    @Value("${app.rabbitmq.geofence-slot-routing-key:geofence.slot.recalculate}")
    private String routingKey;

    @Value("${app.outbox.geofence.batch-size:100}")
    private int batchSize;

    @Value("${app.outbox.geofence.default-max-retry-count:5}")
    private int defaultMaxRetryCount;

    @Value("${app.outbox.geofence.retry-base-seconds:5}")
    private long retryBaseSeconds;

    @Value("${app.outbox.geofence.retry-max-seconds:300}")
    private long retryMaxSeconds;

    //Outbox에 발행할 이벤트 저장
    @Override
    @Transactional
    public void enqueue(Long userId, BigDecimal latitude, BigDecimal longitude, BigDecimal course) {
        OffsetDateTime now = OffsetDateTime.now();
        GeofenceRecalculateOutbox outbox = GeofenceRecalculateOutbox.create(
                userId,
                latitude,
                longitude,
                course,
                defaultMaxRetryCount,
                now
        );
        outboxRepository.save(outbox);
    }

    //5초마다 outbox를 읽어와서 이벤트 발행하는 릴레이 주체
    @Override
    @Scheduled(fixedDelayString = "${app.outbox.geofence.relay-fixed-delay-ms:5000}")
    @Transactional
    public void relayPendingEvents() {
        OffsetDateTime now = OffsetDateTime.now();
        //status=PENDING|RETRY인것과, next_retry가 현재시간보다 빠르거나 같은 outbox만 가져오기
        List<GeofenceRecalculateOutbox> dueEvents =
                outboxRepository.findByStatusInAndNextRetryAtLessThanEqualOrderByIdAsc(
                        List.of(GeofenceOutboxStatus.PENDING, GeofenceOutboxStatus.RETRY),
                        now,
                        PageRequest.of(0, batchSize) //batchSize만큼 가져오고, 첫번째 페이지 가져오기
                );

        for (GeofenceRecalculateOutbox outbox : dueEvents) {
            publishOne(outbox); //이벤트 발행
        }
    }

    //rabbitMQ 이벤트 발행하는 메서드
    private void publishOne(GeofenceRecalculateOutbox outbox) {
        OffsetDateTime now = OffsetDateTime.now();
        outbox.markProcessing(now); //outbox를 처리중으로 상태를 변경
        outboxRepository.save(outbox); //변경한 상태를 저장

        try {
            //이벤트 생성
            GeofenceSlotRecalculateEvent event = new GeofenceSlotRecalculateEvent(
                    outbox.getUserId(),
                    outbox.getLatitude(),
                    outbox.getLongitude(),
                    outbox.getCourse()
            );
            //Spring AMQP에서 메시지를 RabbitMQ로 발행
            //(exchange=어떤 익스체인지로 보낼지,routingKey=어떤 바인딩 규칙으로 라우팅할지,event=실제 payload객체)
            rabbitTemplate.convertAndSend(exchange, routingKey, event);
            outbox.markPublished(OffsetDateTime.now());
            outboxRepository.save(outbox);
        } catch (Exception ex) {
            String error = ex.getClass().getSimpleName() + ": " + ex.getMessage();
            if (outbox.willExceedMaxRetry()) {
                outbox.markDlq(error, OffsetDateTime.now());
                log.error("Outbox moved to DLQ status. outboxId={} userId={} error={}", outbox.getId(), outbox.getUserId(), error);
            } else {
                OffsetDateTime nextRetry = OffsetDateTime.now().plusSeconds(nextRetrySeconds(outbox.getRetryCount()));
                outbox.markRetry(error, nextRetry, OffsetDateTime.now());
                log.warn("Outbox publish failed. outboxId={} retryCount={} nextRetryAt={}",
                        outbox.getId(), outbox.getRetryCount(), nextRetry);
            }
            outboxRepository.save(outbox);
        }
    }

    private long nextRetrySeconds(int retryCount) {
        long exp = retryBaseSeconds * (1L << Math.min(retryCount, 10));
        return Math.min(exp, retryMaxSeconds);
    }
}
