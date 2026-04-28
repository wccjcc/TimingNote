package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.FcmTokenUpsertRequestDto;
import com.timingnote.api.domain.notification.dto.response.FcmTokenUpsertResponseDto;

public interface FcmTokenService {

    FcmTokenUpsertResponseDto upsertToken(Long userId, FcmTokenUpsertRequestDto requestDto);
}
