package com.timingnote.api.domain.user.service;

import com.timingnote.api.domain.user.dto.request.UserRegisterRequestDto;
import com.timingnote.api.domain.user.dto.response.UserRegisterResponseDto;

public interface UserService {

    //디바이스 등록
    UserRegisterResponseDto registerDevice(UserRegisterRequestDto requestDto);
}