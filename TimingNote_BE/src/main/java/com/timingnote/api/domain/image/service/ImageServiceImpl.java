package com.timingnote.api.domain.image.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.image.dto.request.ImageDownloadUrlsRequestDto;
import com.timingnote.api.domain.image.dto.response.ImageDownloadUrlsResponseDto;
import com.timingnote.api.domain.image.dto.request.ImageUploadUrlRequestDto;
import com.timingnote.api.domain.image.dto.response.ImageUploadUrlResponseDto;
import com.timingnote.api.infra.config.S3.PresignedDownloadResponse;
import com.timingnote.api.infra.config.S3.PresignedUploadResponse;
import com.timingnote.api.infra.config.S3.S3PresignedUrlService;
import com.timingnote.api.infra.config.S3.S3Properties;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이미지 업로드 URL 발급 서비스
 */
@Service
@RequiredArgsConstructor
public class ImageServiceImpl implements ImageService {

    // iOS HEIC/HEIF 포함 허용 MIME 목록
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/heic",
            "image/heif"
    );

    private final S3PresignedUrlService s3PresignedUrlService;
    private final S3Properties s3Properties;

    @Override
    @Transactional(readOnly = true)
    public ImageUploadUrlResponseDto createUploadUrl(ImageUploadUrlRequestDto request) {
        validateRequest(request);

        PresignedUploadResponse response = s3PresignedUrlService.createUploadUrl(request.getContentType());

        return ImageUploadUrlResponseDto.builder()
                .uploadSessionId(response.uploadSessionId())
                .imageId(response.imageId())
                .objectKey(response.objectKey())
                .uploadUrl(response.uploadUrl())
                .contentType(response.contentType())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public ImageDownloadUrlsResponseDto createDownloadUrls(ImageDownloadUrlsRequestDto request) {
        var items = request.getObjectKeys().stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .distinct()
                .map(this::createDownloadItem)
                .collect(Collectors.toList());

        return ImageDownloadUrlsResponseDto.builder()
                .items(items)
                .build();
    }

    private ImageDownloadUrlsResponseDto.ImageDownloadUrlItemDto createDownloadItem(String objectKey) {
        PresignedDownloadResponse response = s3PresignedUrlService.createDownloadUrl(objectKey);
        return ImageDownloadUrlsResponseDto.ImageDownloadUrlItemDto.builder()
                .objectKey(response.objectKey())
                .downloadUrl(response.downloadUrl())
                .build();
    }

    private void validateRequest(ImageUploadUrlRequestDto request) {
        if (!ALLOWED_CONTENT_TYPES.contains(request.getContentType())) {
            throw new BusinessException("지원하지 않는 이미지 타입입니다.", ErrorCode.VALIDATION_ERROR);
        }
        if (request.getFileSize() > s3Properties.maxUploadSizeBytes()) {
            throw new BusinessException("이미지 용량이 제한을 초과했습니다. (최대 20MB)", ErrorCode.VALIDATION_ERROR);
        }
    }
}

