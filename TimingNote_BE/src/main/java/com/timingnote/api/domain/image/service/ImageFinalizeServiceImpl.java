package com.timingnote.api.domain.image.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.infra.config.S3.S3Properties;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

/**
 * Todo 수정 완료 시 temp 이미지 키를 최종 original 키로 확정한다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ImageFinalizeServiceImpl implements ImageFinalizeService {

    private final S3Client s3Client;
    private final S3Properties s3Properties;

    @Override
    public List<String> finalizeImageKeys(Long todoId, List<String> imageKeys) {
        if (imageKeys == null || imageKeys.isEmpty()) {
            return List.of();
        }

        final String tempPrefix = s3Properties.originalPrefix() + "/temp/";
        final String finalPrefix = s3Properties.originalPrefix() + "/todos/" + todoId + "/";

        return imageKeys.stream()
                .filter(StringUtils::hasText)
                .map(String::trim)
                .distinct()
                .map(key -> finalizeSingleKey(key, tempPrefix, finalPrefix))
                .filter(Objects::nonNull)
                .toList();
    }

    private String finalizeSingleKey(String key, String tempPrefix, String finalPrefix) {
        if (!key.startsWith(tempPrefix)) {
            // temp 키가 아니면 이미 확정된 키로 간주하고 그대로 사용
            return key;
        }

        final String fileName = extractFileName(key);
        final String destinationKey = finalPrefix + fileName;
        final String bucket = s3Properties.bucket();

        try {
            // 1) temp -> original 최종 경로로 복사
            s3Client.copyObject(CopyObjectRequest.builder()
                    .sourceBucket(bucket)
                    .sourceKey(key)
                    .destinationBucket(bucket)
                    .destinationKey(destinationKey)
                    .build());
            // 2) 복사 성공 후 temp 삭제
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build());
            return destinationKey;
        } catch (S3Exception e) {
            log.error("[Image/Finalize] key 확정 실패 sourceKey={} destinationKey={} message={}",
                    key, destinationKey, e.awsErrorDetails() != null ? e.awsErrorDetails().errorMessage() : e.getMessage());
            throw new BusinessException("이미지 확정 처리에 실패했습니다.", ErrorCode.INTERNAL_SERVER_ERROR);
        }
    }

    private String extractFileName(String key) {
        int idx = key.lastIndexOf('/');
        if (idx < 0 || idx == key.length() - 1) {
            throw new BusinessException("유효하지 않은 이미지 키입니다.", ErrorCode.VALIDATION_ERROR);
        }
        return key.substring(idx + 1);
    }
}

