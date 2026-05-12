package com.timingnote.api.domain.fcm_test.controller;

import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.fcm_test.dto.request.FcmGeofenceTestSendRequestDto;
import com.timingnote.api.domain.fcm_test.service.FcmTestService;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "FCM Test", description = "FCM 테스트 전송 API")
@RestController
@Validated
@RequiredArgsConstructor
@RequestMapping("/api/v1/fcm-test")
public class FcmTestController {

    private final FcmTestService fcmTestService;

    @Operation(
            summary = "Geofence 형식 테스트 푸시 전송",
            description = "유저/슬롯 조회 없이 전달된 token으로 geofence 알림 payload 형식의 FCM 메시지를 전송합니다."
    )
    @PostMapping("/geofence/{slotId}")
    public ApiResponseDto<NotificationGeofenceSendResponseDto> sendGeofenceStylePush(
            @PathVariable @Positive Long slotId,
            @Valid @RequestBody FcmGeofenceTestSendRequestDto requestDto
    ) {
        return ApiResponseDto.success(fcmTestService.sendGeofenceStylePush(slotId, requestDto));
    }
}
