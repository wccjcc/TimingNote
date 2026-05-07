package com.timingnote.api.domain.place.service;

import java.math.BigDecimal;

public interface GenericCandidateRefreshService {

    /**
     * GeofenceRecalculateServiceImpl에서 POST /api/v1/geofence/recalculate 처리 중 호출된다.
     * 사용자의 활성 GENERIC 투두 후보지를 새 좌표 기준으로 Kakao 재검색하여 갱신한다.
     * 기존 후보는 expiresAt = now 로 만료 처리하고, 새 후보를 expiresAt = null 로 삽입한다.
     * 좌표가 없으면 Kakao 검색을 수행할 수 없으므로 즉시 리턴한다.
     */
    void refresh(Long userId, BigDecimal latitude, BigDecimal longitude);
}
