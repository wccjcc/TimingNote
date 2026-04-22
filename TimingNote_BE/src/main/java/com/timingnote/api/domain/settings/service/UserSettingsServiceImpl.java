package com.timingnote.api.domain.settings.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.settings.dto.request.UserSettingsRegisterRequestDto;
import com.timingnote.api.domain.settings.dto.request.UserSettingsUpdateRequestDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsGetResponseDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsRegisterResponseDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsUpdateResponseDto;
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
     * SETTINGS-01 설정 조회: 인증 사용자 기준 최신 설정을 조회한다.
     */
    @Override
    @Transactional(readOnly = true)
    public UserSettingsGetResponseDto getSettings(Long userId) {
        ensureUserExists(userId);

        UserSettings userSettings = userSettingsRepository.findTopByUserIdOrderByUpdatedAtDesc(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        return UserSettingsGetResponseDto.builder()
                .locationAlertEnabled(userSettings.getLocationAlertEnabled())
                .pushAlertEnabled(userSettings.getPushAlertEnabled())
                .radiusM(userSettings.getRadiusM())
                .updatedAt(userSettings.getUpdatedAt().toInstant().toString())
                .build();
    }

    /**
     * SETTINGS-03 설정 등록:
     * 최초 등록이면 생성하고, 기존 설정이 있으면 최신 값으로 재등록한다.
     */
    @Override
    @Transactional
    public UserSettingsRegisterResponseDto registerSettings(Long userId, UserSettingsRegisterRequestDto requestDto) {
        ensureUserExists(userId);

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

    /**
     * SETTINGS-02 설정 수정:
     * 요청에 포함된 필드만 반영하고, 설정이 없으면 기본값으로 생성 후 수정한다.
     */
    @Override
    @Transactional
    public UserSettingsUpdateResponseDto updateSettings(Long userId, UserSettingsUpdateRequestDto requestDto) {
        ensureUserExists(userId);

        UserSettings userSettings = userSettingsRepository.findTopByUserIdOrderByUpdatedAtDesc(userId)
                .orElseGet(() -> new UserSettings(userId, true, true, DEFAULT_RADIUS_M));

        boolean locationAlertEnabled = requestDto.getLocationAlertEnabled() == null
                ? userSettings.getLocationAlertEnabled()
                : requestDto.getLocationAlertEnabled();

        boolean pushAlertEnabled = requestDto.getPushAlertEnabled() == null
                ? userSettings.getPushAlertEnabled()
                : requestDto.getPushAlertEnabled();

        int radiusM = requestDto.getRadiusM() == null
                ? userSettings.getRadiusM()
                : requestDto.getRadiusM();

        validateRadius(radiusM);

        userSettings.apply(locationAlertEnabled, pushAlertEnabled, radiusM);
        UserSettings saved = userSettingsRepository.save(userSettings);

        return UserSettingsUpdateResponseDto.builder()
                .locationAlertEnabled(saved.getLocationAlertEnabled())
                .pushAlertEnabled(saved.getPushAlertEnabled())
                .radiusM(saved.getRadiusM())
                .updatedAt(saved.getUpdatedAt().toInstant().toString())
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
    private void ensureUserExists(Long userId) {
        if (!userRepository.existsById(userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
    }
}
