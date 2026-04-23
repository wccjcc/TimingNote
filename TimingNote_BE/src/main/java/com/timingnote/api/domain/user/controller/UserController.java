package com.timingnote.api.domain.user.controller;

import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.user.dto.request.UserRegisterRequestDto;
import com.timingnote.api.domain.user.dto.response.UserRegisterResponseDto;
import com.timingnote.api.domain.user.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 사용자 디바이스 등록 API 컨트롤러
 */
@Tag(name = "시스템", description = "시스템 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    /**
     * 앱 최초 설치 시 installationUuid 기반 사용자 등록 API
     */
    @Operation(
            summary = "디바이스 등록",
            description = "installationUuid를 기반으로 사용자 레코드를 생성하고 deviceSecret을 발급합니다."
    )
    @PostMapping
    public ApiResponseDto<UserRegisterResponseDto> registerDevice(
            @Valid @RequestBody UserRegisterRequestDto requestDto
    ) {
        return ApiResponseDto.success(userService.registerDevice(requestDto));
    }
}