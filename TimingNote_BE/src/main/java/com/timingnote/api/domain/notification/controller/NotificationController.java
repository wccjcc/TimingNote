package com.timingnote.api.domain.notification.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceSlotsResponseDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;
import com.timingnote.api.domain.notification.service.GeofenceSlotQueryService;
import com.timingnote.api.domain.notification.service.GeofenceSlotSseService;
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
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Tag(name = "Notifications", description = "Notification APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final GeofenceSlotQueryService geofenceSlotQueryService;
    private final GeofenceSlotSseService geofenceSlotSseService;

    @Operation(summary = "위치 기반 알림 발송", description = "Geofence 슬롯 ID 기반으로 위치 알림 발송을 처리한다.")
    @GetMapping("/geofence/{slotId}")
    public ApiResponseDto<NotificationGeofenceSendResponseDto> sendGeofenceNotification(
            @PathVariable Long slotId,
            HttpServletRequest request
    ) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(notificationService.sendGeofenceNotification(userId, slotId), "알림 처리 완료");
    }

    @Operation(summary = "Geofence 슬롯 SSE 구독", description = "슬롯 변경 이벤트를 SSE로 구독한다.")
    @GetMapping(value = "/geofence/slots/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribeGeofenceSlots(HttpServletRequest request) {
        Long userId = extractAuthenticatedUserId(request);
        return geofenceSlotSseService.subscribe(userId);
    }

    @Operation(summary = "활성 Geofence 슬롯 조회", description = "현재 사용자 기준 활성 슬롯 목록을 조회한다.")
    @GetMapping("/geofence/slots")
    public ApiResponseDto<GeofenceSlotsResponseDto> getGeofenceSlots(HttpServletRequest request) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(geofenceSlotQueryService.getActiveSlots(userId));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
