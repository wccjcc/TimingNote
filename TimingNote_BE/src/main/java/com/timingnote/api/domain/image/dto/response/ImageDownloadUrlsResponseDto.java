package com.timingnote.api.domain.image.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@Schema(description = "이미지 Presigned GET URL 발급 응답")
public class ImageDownloadUrlsResponseDto {

    @Schema(description = "ObjectKey 별 다운로드 URL 목록")
    private List<ImageDownloadUrlItemDto> items;

    @Getter
    @Builder
    @Schema(description = "ObjectKey 별 다운로드 URL")
    public static class ImageDownloadUrlItemDto {
        @Schema(description = "S3 Object Key")
        private String objectKey;

        @Schema(description = "S3 Presigned GET URL")
        private String downloadUrl;
    }
}

