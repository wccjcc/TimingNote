package com.timingnote.api.domain.image.service;

import com.timingnote.api.domain.image.dto.request.ImageResizeCallbackRequestDto;

public interface ImageCallbackService {

    void handleResizeCallback(ImageResizeCallbackRequestDto request);
}

