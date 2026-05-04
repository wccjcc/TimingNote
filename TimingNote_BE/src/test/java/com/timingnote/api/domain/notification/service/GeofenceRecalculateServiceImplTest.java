package com.timingnote.api.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class GeofenceRecalculateServiceImplTest {

    @Mock
    private GeofenceRecalculateOutboxService geofenceRecalculateOutboxService;

    @InjectMocks
    private GeofenceRecalculateServiceImpl geofenceRecalculateService;

    @Test
    void requestRecalculation_success_when_validRequest() {
        // given: 유효한 위도/경도/course를 가진 재계산 요청이 준비되어 있다.
        Long userId = 1L;
        GeofenceRecalculateRequestDto requestDto = createRequestDto(
                new BigDecimal("37.5665"),
                new BigDecimal("126.9780"),
                new BigDecimal("120.0")
        );

        // when: 재계산 요청을 수행한다.
        GeofenceRecalculateResponseDto response = geofenceRecalculateService.requestRecalculation(userId, requestDto);

        // then: outbox enqueue가 정확한 인자로 1회 호출되고, API 응답은 accepted/enqueued를 반환해야 한다.
        verify(geofenceRecalculateOutboxService).enqueue(
                userId,
                requestDto.getLatitude(),
                requestDto.getLongitude(),
                requestDto.getCourse()
        );
        assertThat(response.isAccepted()).isTrue();
        assertThat(response.getStatus()).isEqualTo("ENQUEUED");
    }

    @Test
    void requestRecalculation_fail400_when_latitudeOrLongitudeMissing() {
        // given: 위도(latitude)가 null인 잘못된 요청이 준비되어 있다.
        Long userId = 1L;
        GeofenceRecalculateRequestDto requestDto = createRequestDto(
                null,
                new BigDecimal("126.9780"),
                new BigDecimal("120.0")
        );

        // when & then: 서비스가 BAD_REQUEST 성격의 BusinessException을 던져야 하며, outbox는 호출되면 안 된다.
        assertThatThrownBy(() -> geofenceRecalculateService.requestRecalculation(userId, requestDto))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.INVALID_GEOFENCE_RECALCULATE_REQUEST);

        verifyNoInteractions(geofenceRecalculateOutboxService);
    }

    @Test
    void requestRecalculation_fail500_when_enqueueThrowsException() {
        // given: 요청은 유효하지만 outbox enqueue 단계에서 예외가 발생하도록 구성한다.
        Long userId = 1L;
        GeofenceRecalculateRequestDto requestDto = createRequestDto(
                new BigDecimal("37.5665"),
                new BigDecimal("126.9780"),
                new BigDecimal("120.0")
        );
        doThrow(new RuntimeException("rabbit publish failed"))
                .when(geofenceRecalculateOutboxService)
                .enqueue(userId, requestDto.getLatitude(), requestDto.getLongitude(), requestDto.getCourse());

        // when & then: 서비스는 내부 예외를 BusinessException(500 코드)로 변환해서 던져야 한다.
        assertThatThrownBy(() -> geofenceRecalculateService.requestRecalculation(userId, requestDto))
                .isInstanceOf(BusinessException.class)
                .extracting(ex -> ((BusinessException) ex).getErrorCode())
                .isEqualTo(ErrorCode.GEOFENCE_RECALCULATE_ENQUEUE_FAILED);
    }

    private GeofenceRecalculateRequestDto createRequestDto(
            BigDecimal latitude,
            BigDecimal longitude,
            BigDecimal course
    ) {
        GeofenceRecalculateRequestDto requestDto = new GeofenceRecalculateRequestDto();
        ReflectionTestUtils.setField(requestDto, "latitude", latitude);
        ReflectionTestUtils.setField(requestDto, "longitude", longitude);
        ReflectionTestUtils.setField(requestDto, "course", course);
        ReflectionTestUtils.setField(requestDto, "occurredAt", OffsetDateTime.now());
        return requestDto;
    }
}
