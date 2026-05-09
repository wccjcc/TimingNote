package com.timingnote.api.domain.image.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * Lambda 이미지 리사이즈 완료 콜백 응답 DTO
 */
@Getter
@Builder
@Schema(description = "이미지 리사이즈 완료 콜백 응답")
public class ImageResizeCallbackResponseDto {

    @Schema(description = "수신 확인 여부", example = "true")
    private boolean acknowledged;
}

