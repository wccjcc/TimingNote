package com.timingnote.api.infra.config.S3;

public record PresignedUploadResponse(
        String uploadSessionId,
        String imageId,
        String objectKey,
        String uploadUrl,
        String contentType
) {
}
