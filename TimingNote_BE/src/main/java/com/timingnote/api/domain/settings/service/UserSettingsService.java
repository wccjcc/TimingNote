package com.timingnote.api.domain.settings.service;

import com.timingnote.api.domain.settings.dto.request.UserSettingsRegisterRequestDto;
import com.timingnote.api.domain.settings.dto.request.UserSettingsUpdateRequestDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsGetResponseDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsRegisterResponseDto;
import com.timingnote.api.domain.settings.dto.response.UserSettingsUpdateResponseDto;

public interface UserSettingsService {

    // SETTINGS-01 설정 조회 처리
    UserSettingsGetResponseDto getSettings(Long userId);

    // SETTINGS-03 설정 등록(최초/재등록) 처리
    UserSettingsRegisterResponseDto registerSettings(Long userId, UserSettingsRegisterRequestDto requestDto);
    // SETTINGS-02 설정 수정(부분 업데이트) 처리
    UserSettingsUpdateResponseDto updateSettings(Long userId, UserSettingsUpdateRequestDto requestDto);
}
