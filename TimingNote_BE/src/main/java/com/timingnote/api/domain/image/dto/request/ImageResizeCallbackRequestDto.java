package com.timingnote.api.domain.image.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Lambda 이미지 리사이즈 완료 콜백 요청 DTO
 */
@Getter
@NoArgsConstructor
@Schema(description = "이미지 리사이즈 완료 콜백 요청")
public class ImageResizeCallbackRequestDto {

    @NotBlank
    @Schema(description = "원본 이미지 key", example = "uploads/original/todos/10/abc.jpg")
    private String originalKey;

    @Schema(description = "리사이즈 이미지 key", example = "uploads/resized/todos/10/abc_1536.jpg")
    private String resizedKey;

    @Schema(description = "리사이즈 이미지 URL", example = "https://cdn.example.com/uploads/resized/todos/10/abc_1536.jpg")
    private String resizedUrl;

    @NotBlank
    @Schema(description = "처리 상태 (SUCCESS | FAILED)", example = "SUCCESS")
    private String status;

    @Schema(description = "실패 메시지", example = "Unsupported format")
    private String errorMessage;
}

