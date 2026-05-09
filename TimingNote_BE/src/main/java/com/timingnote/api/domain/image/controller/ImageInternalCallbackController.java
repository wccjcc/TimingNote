package com.timingnote.api.domain.image.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.image.dto.request.ImageResizeCallbackRequestDto;
import com.timingnote.api.domain.image.dto.response.ImageResizeCallbackResponseDto;
import com.timingnote.api.domain.image.service.ImageCallbackService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Lambda 내부 콜백 API
 */
@Tag(name = "Image Internal", description = "이미지 내부 콜백 API")
@RestController
@RequestMapping("/internal/images")
@RequiredArgsConstructor
public class ImageInternalCallbackController {

    private final ImageCallbackService imageCallbackService;

    @Value("${ai.internal.secret}")
    private String internalSecret;

    @Operation(
            summary = "이미지 리사이즈 완료 콜백",
            description = "Lambda가 리사이즈 결과를 전달하면 original key를 resized key로 치환한다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수신 성공"),
            @ApiResponse(responseCode = "403", description = "내부 인증 실패",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    })
    @PostMapping("/callback")
    public ApiResponseDto<ImageResizeCallbackResponseDto> callback(
            @Parameter(description = "내부 통신 시크릿", required = true)
            @RequestHeader("X-Internal-Secret") String headerSecret,
            @Valid @RequestBody ImageResizeCallbackRequestDto request) {
        validateInternalSecret(headerSecret);
        imageCallbackService.handleResizeCallback(request);
        return ApiResponseDto.success(
                ImageResizeCallbackResponseDto.builder()
                        .acknowledged(true)
                        .build()
        );
    }

    private void validateInternalSecret(String headerSecret) {
        if (!internalSecret.equals(headerSecret)) {
            throw new BusinessException("내부 인증에 실패했습니다.", ErrorCode.FORBIDDEN);
        }
    }
}

