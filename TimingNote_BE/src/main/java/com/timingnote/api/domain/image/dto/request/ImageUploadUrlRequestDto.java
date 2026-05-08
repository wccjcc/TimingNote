package com.timingnote.api.domain.image.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 이미지 Presigned URL 발급 요청 DTO
 */
@Getter
@NoArgsConstructor
@Schema(description = "이미지 업로드용 Presigned URL 발급 요청")
public class ImageUploadUrlRequestDto {

    @NotBlank
    @Schema(description = "이미지 MIME 타입", example = "image/jpeg")
    private String contentType;

    @NotNull
    @Positive
    @Schema(description = "업로드 파일 크기(bytes)", example = "5242880")
    private Long fileSize;
}

