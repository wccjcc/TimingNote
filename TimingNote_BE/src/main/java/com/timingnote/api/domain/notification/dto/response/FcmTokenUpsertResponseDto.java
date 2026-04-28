package com.timingnote.api.domain.notification.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * SYS-02 FCM 토큰 갱신/등록 응답 DTO
 */
@Getter
@Builder
public class FcmTokenUpsertResponseDto {

    @Schema(description = "인증된 사용자 ID", example = "1")
    private Long userId;

    @Schema(description = "활성 상태", example = "true")
    private Boolean isActive;

    @Schema(description = "생성 시각(UTC)", example = "2026-04-19T09:50:00Z")
    private String createdAt;

    @Schema(description = "갱신 시각(UTC)", example = "2026-04-19T10:00:00Z")
    private String updatedAt;
}
