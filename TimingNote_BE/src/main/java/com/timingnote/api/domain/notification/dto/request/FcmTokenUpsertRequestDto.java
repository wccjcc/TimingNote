package com.timingnote.api.domain.notification.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * SYS-02 FCM 토큰 갱신/등록 요청 DTO
 */
@Getter
@NoArgsConstructor
public class FcmTokenUpsertRequestDto {

    @Schema(description = "FCM에서 발급된 최신 토큰", example = "fCm_token_string...")
    @NotBlank(message = "fcmToken은 필수입니다.")
    private String fcmToken;

    @Schema(description = "플랫폼", example = "IOS")
    @NotBlank(message = "platform은 필수입니다.")
    @Pattern(regexp = "^(IOS|ANDROID|WEB)$", message = "platform은 IOS, ANDROID, WEB 중 하나여야 합니다.")
    private String platform;

    @Schema(description = "활성 상태", example = "true")
    @NotNull(message = "isActive는 필수입니다.")
    private Boolean isActive;
}
