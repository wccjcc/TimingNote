package com.timingnote.api.domain.image.service;

import com.timingnote.api.domain.image.dto.request.ImageUploadUrlRequestDto;
import com.timingnote.api.domain.image.dto.response.ImageUploadUrlResponseDto;

public interface ImageService {

    ImageUploadUrlResponseDto createUploadUrl(ImageUploadUrlRequestDto request);
}

