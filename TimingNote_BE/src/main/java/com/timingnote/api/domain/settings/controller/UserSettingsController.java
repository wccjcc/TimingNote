package com.timingnote.api.domain.settings.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.settings.dto.request.UserSettingsRegisterRequestDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsGetResponseDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsRegisterResponseDto;
import com.timingnote.api.domain.settings.service.UserSettingsService;
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
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 사용자 알림 기본 설정 API 컨트롤러
 */
@Tag(name = "설정", description = "사용자 알림 기본 설정 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users/me/settings")
public class UserSettingsController {

    private final UserSettingsService userSettingsService;

    /**
     * SETTINGS-01: 사용자 알림 기본 설정 조회
     */
    @Operation(
            summary = "설정 조회",
            description = "사용자의 최신 알림 기본 설정을 조회한다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "성공"),
            @ApiResponse(
                    responseCode = "401",
                    description = "유효하지 않은 Device Secret",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            ),
            @ApiResponse(
                    responseCode = "404",
                    description = "설정 레코드 없음",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            )
    })
    @GetMapping
    public ApiResponseDto<UserSettingsGetResponseDto> getSettings(HttpServletRequest request) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(userSettingsService.getSettings(userId));
    }

    /**
     * SETTINGS-03: 사용자 알림 기본 설정 등록
     */
    @Operation(
            summary = "설정 등록",
            description = "사용자 알림 기본값(위치 알림, 푸시 알림, 반경)을 등록한다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "성공"),
            @ApiResponse(
                    responseCode = "400",
                    description = "반경 범위 초과 또는 타입 오류",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            ),
            @ApiResponse(
                    responseCode = "401",
                    description = "유효하지 않은 Device Secret",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class))
            )
    })
    @PostMapping
    public ApiResponseDto<UserSettingsRegisterResponseDto> registerSettings(
            @Valid @RequestBody(required = false) UserSettingsRegisterRequestDto requestDto,
            HttpServletRequest request
    ) {
        UserSettingsRegisterRequestDto effectiveRequestDto =
                requestDto == null ? new UserSettingsRegisterRequestDto() : requestDto;

        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(userSettingsService.registerSettings(userId, effectiveRequestDto));
    }

    // 인터셉터에서 저장한 인증 사용자 ID를 조회한다.
    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
