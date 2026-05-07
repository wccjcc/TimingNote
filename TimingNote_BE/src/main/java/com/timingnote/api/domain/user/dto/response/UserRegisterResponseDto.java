package com.timingnote.api.domain.user.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * SYS-01 디바이스 등록 응답 DTO
 */
@Getter
@Builder
public class UserRegisterResponseDto {

    @Schema(description = "사용자 PK", example = "1")
    private Long userId;

    @Schema(description = "디바이스 인증 비밀키", example = "a1b2c3d4e5f6...")
    private String deviceSecret;

    @Schema(description = "사용자 생성 시각 (ISO 8601)", example = "2026-04-19T10:00:00Z")
    private String createdAt;

    @Schema(description = "신규 등록 유저인지 여부", example="true")
    private Boolean isNewUser;
}