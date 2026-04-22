package com.timingnote.api.domain.settings.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.settings.dto.request.UserSettingsRegisterRequestDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsRegisterResponseDto;
import com.timingnote.api.domain.settings.entity.UserSettings;
import com.timingnote.api.domain.settings.repository.UserSettingsRepository;
import com.timingnote.api.domain.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserSettingsServiceImpl implements UserSettingsService {

    private static final int DEFAULT_RADIUS_M = 100;
    private static final int MIN_RADIUS_M = 50;
    private static final int MAX_RADIUS_M = 20000;

    private final UserRepository userRepository;
    private final UserSettingsRepository userSettingsRepository;

    /**
     * SETTINGS-03 설정 등록:
     * 최초 등록이면 생성하고, 기존 설정이 있으면 최신 값으로 재등록한다.
     */
    @Override
    @Transactional
    public UserSettingsRegisterResponseDto registerSettings(Long userId, UserSettingsRegisterRequestDto requestDto) {
        if (!userRepository.existsById(userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        boolean locationAlertEnabled = resolveLocationAlertEnabled(requestDto);
        boolean pushAlertEnabled = resolvePushAlertEnabled(requestDto);
        int radiusM = resolveRadiusM(requestDto);
        validateRadius(radiusM);

        UserSettings userSettings = userSettingsRepository.findTopByUserIdOrderByCreatedAtDesc(userId)
                .orElseGet(() -> new UserSettings(userId, locationAlertEnabled, pushAlertEnabled, radiusM));

        userSettings.apply(locationAlertEnabled, pushAlertEnabled, radiusM);
        UserSettings saved = userSettingsRepository.save(userSettings);

        return UserSettingsRegisterResponseDto.builder()
                .locationAlertEnabled(saved.getLocationAlertEnabled())
                .pushAlertEnabled(saved.getPushAlertEnabled())
                .radiusM(saved.getRadiusM())
                .createdAt(saved.getCreatedAt().toInstant().toString())
                .build();
    }

    private boolean resolveLocationAlertEnabled(UserSettingsRegisterRequestDto requestDto) {
        return requestDto.getLocationAlertEnabled() == null || requestDto.getLocationAlertEnabled();
    }

    private boolean resolvePushAlertEnabled(UserSettingsRegisterRequestDto requestDto) {
        return requestDto.getPushAlertEnabled() == null || requestDto.getPushAlertEnabled();
    }

    private int resolveRadiusM(UserSettingsRegisterRequestDto requestDto) {
        return requestDto.getRadiusM() == null ? DEFAULT_RADIUS_M : requestDto.getRadiusM();
    }

    private void validateRadius(int radiusM) {
        if (radiusM < MIN_RADIUS_M || radiusM > MAX_RADIUS_M) {
            throw new BusinessException(
                    String.format("radiusM는 %d 이상 %d 이하여야 합니다.", MIN_RADIUS_M, MAX_RADIUS_M),
                    ErrorCode.VALIDATION_ERROR
            );
        }
    }
}
