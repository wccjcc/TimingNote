package com.timingnote.api.domain.notification.service;

import java.math.BigDecimal;

public interface GeofenceRecalculateOutboxService {

    //geofence 계산 큐에 적재하는 메서드
    void enqueue(Long userId, BigDecimal latitude, BigDecimal longitude, BigDecimal course);

    void relayPendingEvents();
}
