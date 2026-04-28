package com.timingnote.api.domain.notification.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.service.NotificationService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * NOTI 도메인 API 컨트롤러.
 */
@Tag(name = "알림", description = "알림 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    /**
     * NOTI-05: Geofence 진입 기반 알림 발송.
     */
    @Operation(summary = "위치 기반 알림 발송", description = "Geofence slotId를 기준으로 알림 조건을 확인하고 FCM 알림을 발송한다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "성공"),
            @ApiResponse(
                    responseCode = "401",
                    description = "유효하지 않은 Device Secret",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            ),
            @ApiResponse(
                    responseCode = "404",
                    description = "해당 geofence slot 없음",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            )
    })
    @GetMapping("/geofence/{slotId}")
    public ApiResponseDto<NotificationGeofenceSendResponseDto> sendGeofenceNotification(
            @PathVariable Long slotId,
            HttpServletRequest request
    ) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(notificationService.sendGeofenceNotification(userId, slotId), "알림 처리 완료");
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
