package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.FcmTokenUpsertRequestDto;
import com.timingnote.api.domain.notification.dto.response.FcmTokenUpsertResponseDto;
import com.timingnote.api.domain.notification.entity.UserFcmToken;
import com.timingnote.api.domain.notification.repository.UserFcmTokenRepository;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * SYS-02 FCM 토큰 upsert 서비스
 */
@Service
@RequiredArgsConstructor
public class FcmTokenServiceImpl implements FcmTokenService {

    private final UserFcmTokenRepository userFcmTokenRepository;

    /**
     * 사용자 기준 토큰 upsert.
     * - 기존 user 토큰이 있으면 갱신
     * - 없으면 token 기준으로 재사용 후 사용자 재매핑
     * - 둘 다 없으면 신규 생성
     */
    @Override
    @Transactional
    public FcmTokenUpsertResponseDto upsertToken(Long userId, FcmTokenUpsertRequestDto requestDto) {
        String normalizedToken = requestDto.getFcmToken().trim();
        String normalizedPlatform = requestDto.getPlatform().trim().toUpperCase(Locale.ROOT);

        UserFcmToken saved = userFcmTokenRepository.findByUserId(userId)
                .map(entity -> {
                    entity.apply(userId, normalizedToken, normalizedPlatform, requestDto.getIsActive());
                    return userFcmTokenRepository.save(entity);
                })
                .orElseGet(() -> userFcmTokenRepository.findByFcmToken(normalizedToken)
                        .map(entity -> {
                            entity.apply(userId, normalizedToken, normalizedPlatform, requestDto.getIsActive());
                            return userFcmTokenRepository.save(entity);
                        })
                        .orElseGet(() -> userFcmTokenRepository.save(
                                new UserFcmToken(userId, normalizedToken, normalizedPlatform, requestDto.getIsActive())
                        )));

        return FcmTokenUpsertResponseDto.builder()
                .userId(saved.getUserId())
                .isActive(saved.getIsActive())
                .createdAt(saved.getCreatedAt().toInstant().toString())
                .updatedAt(saved.getUpdatedAt().toInstant().toString())
                .build();
    }
}
