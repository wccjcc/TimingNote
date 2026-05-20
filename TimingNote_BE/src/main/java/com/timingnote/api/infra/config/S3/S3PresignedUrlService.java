package com.timingnote.api.infra.config.S3;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.time.Duration;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class S3PresignedUrlService {

    private final S3Presigner s3Presigner;
    private final S3Properties s3Properties;

    public PresignedUploadResponse createUploadUrl(String contentType) {
        String uploadSessionId = UUID.randomUUID().toString();
        String imageId = UUID.randomUUID().toString();

        String extension = resolveExtension(contentType);
        String objectKey = "%s/temp/%s/%s.%s".formatted(
                s3Properties.originalPrefix(),
                uploadSessionId,
                imageId,
                extension
        );

        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                .bucket(s3Properties.bucket())
                .key(objectKey)
                .contentType(contentType)
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(s3Properties.presignedUrlExpirationMinutes()))
                .putObjectRequest(putObjectRequest)
                .build();

        PresignedPutObjectRequest presignedRequest =
                s3Presigner.presignPutObject(presignRequest);

        return new PresignedUploadResponse(
                uploadSessionId,
                imageId,
                objectKey,
                presignedRequest.url().toString(),
                contentType
        );
    }

    public PresignedDownloadResponse createDownloadUrl(String objectKey) {
        GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                .bucket(s3Properties.bucket())
                .key(objectKey)
                .build();

        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(s3Properties.presignedUrlExpirationMinutes()))
                .getObjectRequest(getObjectRequest)
                .build();

        PresignedGetObjectRequest presignedRequest =
                s3Presigner.presignGetObject(presignRequest);

        return new PresignedDownloadResponse(
                objectKey,
                presignedRequest.url().toString()
        );
    }

    private String resolveExtension(String contentType) {
        if ("image/jpeg".equals(contentType)) {
            return "jpg";
        }
        if ("image/png".equals(contentType)) {
            return "png";
        }
        if ("image/webp".equals(contentType)) {
            return "webp";
        }
        if ("image/heic".equals(contentType)) {
            return "heic";
        }
        if ("image/heif".equals(contentType)) {
            return "heif";
        }
        throw new IllegalArgumentException("지원하지 않는 이미지 타입입니다: " + contentType);
    }
}
