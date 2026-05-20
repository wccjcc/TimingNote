package com.timingnote.api.domain.notification.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.notification.dto.request.GeofenceRecalculateRequestDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceRecalculateResponseDto;
import com.timingnote.api.domain.notification.service.GeofenceRecalculateService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Geofence 이벤트 관련 API 컨트롤러.
 */
@Tag(name = "Geofence", description = "Geofence APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/geofence")
public class GeofenceController {

    private final GeofenceRecalculateService geofenceRecalculateService;

    /**
     * 중요 위치 변경 시 Geofence 슬롯 재계산을 요청한다.
     */
    @Operation(
            summary = "Geofence 슬롯 재계산 요청",
            description = "중요 위치 변경 이벤트를 수신해 Geofence 슬롯 재계산을 비동기로 요청한다."
    )
    @PostMapping("/recalculate")
    public ApiResponseDto<GeofenceRecalculateResponseDto> requestRecalculation(
            @Valid @RequestBody GeofenceRecalculateRequestDto requestDto,
            HttpServletRequest request
    ) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(geofenceRecalculateService.requestRecalculation(userId, requestDto));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}

