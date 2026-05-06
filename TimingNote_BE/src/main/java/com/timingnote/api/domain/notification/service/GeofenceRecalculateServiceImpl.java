package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
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
        if (requestDto == null || requestDto.getLatitude() == null || requestDto.getLongitude() == null) {
            throw new BusinessException(ErrorCode.INVALID_GEOFENCE_RECALCULATE_REQUEST);
        }
        try {
            geofenceRecalculateOutboxService.enqueue(
                    userId,
                    requestDto.getLatitude(),
                    requestDto.getLongitude(),
                    requestDto.getCourse()
            );
        } catch (Exception ex) {
            throw new BusinessException(
                    "Geofence recalculation event enqueue failed.",
                    ErrorCode.GEOFENCE_RECALCULATE_ENQUEUE_FAILED
            );
        }

        return GeofenceRecalculateResponseDto.builder()
                .accepted(true)
                .status("ENQUEUED")
                .build();
    }
}
