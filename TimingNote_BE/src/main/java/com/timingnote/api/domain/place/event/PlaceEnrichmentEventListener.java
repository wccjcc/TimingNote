package com.timingnote.api.domain.place.event;

import com.timingnote.api.domain.place.service.PlaceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Google 영업시간 보강 이벤트 리스너 — 트랜잭션 커밋 후 비동기로 처리.
 *
 * <p>왜 별도 빈인가:
 * <ul>
 *   <li>self-invocation 함정 방지 — PlaceServiceImpl에서 자기 자신의 @Async 메서드를
 *       호출하면 프록시를 안 거쳐 비동기로 동작하지 않는다.</li>
 *   <li>트랜잭션 분리 — 리스너는 새 트랜잭션을 시작 ({@code PlaceService}의 메서드들이
 *       각자 {@code @Transactional}). placeId로 다시 로드하므로 detached 엔티티 문제도 없다.</li>
 *   <li>{@code @TransactionalEventListener(AFTER_COMMIT)} 보장 — Place 저장 트랜잭션이
 *       롤백되면 이벤트가 발행됐어도 리스너는 호출되지 않는다 (외부 API 부정확 호출 방지).</li>
 * </ul>
 *
 * <p>실패 처리: 예외는 catch해서 로그만 남기고 삼킨다.
 * 보강은 best-effort이며, TTL 만료 검사로 다음 진입 시 자연스럽게 재시도된다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PlaceEnrichmentEventListener {

    private final PlaceService placeService;

    @Async("googleEnrichmentExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onSinglePlaceEnrichment(PlaceEnrichmentRequestedEvent event) {
        try {
            switch (event.type()) {
                case INITIAL -> placeService.enrichOpeningHoursByPlaceId(event.placeId());
                case REFRESH -> placeService.refreshOpeningHoursByPlaceId(event.placeId());
            }
        } catch (Exception e) {
            log.error("[PlaceEnrichment] 처리 실패 placeId={} type={}: {}",
                    event.placeId(), event.type(), e.getMessage(), e);
        }
    }

    @Async("googleEnrichmentExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onCandidateBatchEnrichment(CandidateBatchEnrichmentEvent event) {
        try {
            placeService.enrichCandidatesByPlaceIds(
                    event.placeIds(), event.placeText(),
                    event.latitude(), event.longitude());
        } catch (Exception e) {
            log.error("[PlaceEnrichment/Batch] 처리 실패 placeText='{}' (size={}): {}",
                    event.placeText(), event.placeIds().size(), e.getMessage(), e);
        }
    }
}
