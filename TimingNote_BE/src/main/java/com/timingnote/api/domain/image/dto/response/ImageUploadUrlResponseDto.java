package com.timingnote.api.domain.image.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * 이미지 Presigned URL 발급 응답 DTO
 */
@Getter
@Builder
@Schema(description = "이미지 업로드용 Presigned URL 발급 응답")
public class ImageUploadUrlResponseDto {

    @Schema(description = "업로드 세션 ID")
    private String uploadSessionId;

    @Schema(description = "이미지 ID")
    private String imageId;

    @Schema(description = "S3 Object Key")
    private String objectKey;

    @Schema(description = "S3 Presigned PUT URL")
    private String uploadUrl;

    @Schema(description = "MIME 타입")
    private String contentType;
}

