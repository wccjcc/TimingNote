package com.timingnote.api.infra.config.S3;

public record PresignedDownloadResponse(
        String objectKey,
        String downloadUrl
) {
}
