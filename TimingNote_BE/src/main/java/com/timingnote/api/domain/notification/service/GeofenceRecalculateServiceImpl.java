package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import com.timingnote.api.domain.place.service.GenericCandidateRefreshService;
import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * POST /api/v1/geofence/recalculate 핸들러.
 *
 * <p>메서드에 {@code @Transactional}을 두지 않는 이유: Kakao HTTP 호출을 트랜잭션 안에 두면
 * HikariCP 커넥션이 응답 대기 시간 동안 점유된다. refresh는 트랜잭션 없이, enqueue는 자체
 * 짧은 트랜잭션으로 분리한다.
 */
@Service
@RequiredArgsConstructor
public class GeofenceRecalculateServiceImpl implements GeofenceRecalculateService {

    private final GenericCandidateRefreshService refreshService;
    private final GeofenceRecalculateOutboxService outboxService;

    @Override
    public GeofenceRecalculateResponseDto requestRecalculation(Long userId, GeofenceRecalculateRequestDto requestDto) {
        if (requestDto == null || requestDto.getLatitude() == null || requestDto.getLongitude() == null) {
            throw new BusinessException(ErrorCode.INVALID_GEOFENCE_RECALCULATE_REQUEST);
        }
        try {
            refreshService.refresh(userId, requestDto.getLatitude(), requestDto.getLongitude(), requestDto.getCourse());
            outboxService.enqueue(
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
