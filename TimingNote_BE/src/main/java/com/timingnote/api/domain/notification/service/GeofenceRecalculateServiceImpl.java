package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import com.timingnote.api.domain.place.service.GenericCandidateRefreshService;
import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Geofence 재계산 요청 서비스.
 *
 * <p>POST /api/v1/geofence/recalculate 의 핸들러로, 유의미한 위치 이동 이벤트를 처리한다.
 * <ol>
 *   <li>{@link GenericCandidateRefreshService#refresh}: GENERIC 후보지를 새 좌표 기준으로
 *       Kakao 재검색하여 todo_candidate_places 갱신 (HTTP 트랜잭션 밖, DB는 per-todo 짧은 트랜잭션)</li>
 *   <li>{@link GeofenceRecalculateOutboxService#enqueue}: 슬롯 재계산 이벤트를 outbox에 적재.
 *       릴레이 → RabbitMQ → Consumer → recalculateSlots 흐름으로 비동기 처리</li>
 * </ol>
 *
 * <p>메서드 자체에 {@code @Transactional}을 두지 않는 이유:
 * Kakao HTTP 호출이 트랜잭션 안에 들어가면 HikariCP 커넥션이 응답 대기 시간 동안 점유된다.
 * refresh()는 트랜잭션 없이, enqueue()는 자체 짧은 트랜잭션으로 분리한다.
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
            // 1) GENERIC 후보 재검색 (Kakao) — 트랜잭션 밖
            refreshService.refresh(userId, requestDto.getLatitude(), requestDto.getLongitude());

            // 2) 슬롯 재계산 이벤트를 outbox에 적재 — enqueue 자체의 짧은 트랜잭션
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
