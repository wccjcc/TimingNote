package com.timingnote.api.domain.place.event;

import java.util.List;

/**
 * GENERIC 후보(여러 Place) 일괄 영업시간 보강 요청.
 *
 * <p>한 번의 Google TextSearch 호출로 N개 후보를 매칭하므로 batch 단위 이벤트로 처리.
 * 단건 단위로 N번 호출하는 것보다 quota·정확도 모두 유리.
 */
public record CandidateBatchEnrichmentEvent(
        List<Long> placeIds,
        String placeText,
        double latitude,
        double longitude
) {}
