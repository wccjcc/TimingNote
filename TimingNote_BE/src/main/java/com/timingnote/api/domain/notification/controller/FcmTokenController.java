package com.timingnote.api.domain.notification.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.notification.dto.request.FcmTokenUpsertRequestDto;
import com.timingnote.api.domain.notification.dto.response.FcmTokenUpsertResponseDto;
import com.timingnote.api.domain.notification.service.FcmTokenService;
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
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * SYS-02 FCM 토큰 갱신 API 컨트롤러
 */
@Tag(name = "시스템", description = "FCM 토큰 관리 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/fcm")
public class FcmTokenController {

    private final FcmTokenService fcmTokenService;

    /**
     * 앱 시작 시 FCM 토큰을 등록/갱신한다.
     */
    @Operation(summary = "FCM 토큰 갱신", description = "기존 토큰을 최신 토큰으로 교체(upsert)합니다.")
    @PatchMapping("/tokens")
    public ApiResponseDto<FcmTokenUpsertResponseDto> upsertFcmToken(
            @Valid @RequestBody FcmTokenUpsertRequestDto requestDto,
            HttpServletRequest request
    ) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(fcmTokenService.upsertToken(userId, requestDto));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
