package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Geofence 재계산 요청 서비스.
 */
@Service
@RequiredArgsConstructor
public class GeofenceRecalculateServiceImpl implements GeofenceRecalculateService {

    private final GeofenceRecalculateOutboxService geofenceRecalculateOutboxService;

    @Override
    @Transactional
    public GeofenceRecalculateResponseDto requestRecalculation(Long userId, GeofenceRecalculateRequestDto requestDto) {
        // 중요 위치 변경 이벤트를 outbox에 적재하고 비동기 릴레이로 전달한다.
        geofenceRecalculateOutboxService.enqueue(
                userId,
                requestDto.getLatitude(),
                requestDto.getLongitude(),
                requestDto.getCourse()
        );

        return GeofenceRecalculateResponseDto.builder()
                .accepted(true)
                .status("ENQUEUED")
                .build();
    }
}
