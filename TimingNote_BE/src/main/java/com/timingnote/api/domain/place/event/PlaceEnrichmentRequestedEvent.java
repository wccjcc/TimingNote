package com.timingnote.api.domain.place.event;

/**
 * 단일 Place에 대한 Google 영업시간 보강 요청 이벤트.
 *
 * <p>Producer: Place 저장 트랜잭션 내에서 publish.
 * Consumer: {@code @TransactionalEventListener(AFTER_COMMIT) + @Async} 리스너가 처리.
 *
 * @param placeId Place 엔티티 ID
 * @param type   INITIAL(googlePlaceId 없음, 최초 보강) / REFRESH(TTL 만료, 갱신)
 */
public record PlaceEnrichmentRequestedEvent(Long placeId, EnrichmentType type) {

    public enum EnrichmentType {
        /** 최초 보강 — TextSearch로 후보 매칭 후 저장. */
        INITIAL,
        /** TTL 만료 갱신 — 이미 알려진 googlePlaceId로 Place Details 호출. */
        REFRESH
    }
}
