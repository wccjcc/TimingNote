package com.timingnote.api.infra.config.S3;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.s3")
public record S3Properties(
        String bucket,
        Long presignedUrlExpirationMinutes,
        Long maxUploadSizeBytes,
        String originalPrefix,
        String resizedPrefix,
        String thumbnailPrefix
) {
}
