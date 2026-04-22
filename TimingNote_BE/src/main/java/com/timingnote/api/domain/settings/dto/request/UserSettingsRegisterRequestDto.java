package com.timingnote.api.domain.settings.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * SETTINGS-03 설정 등록 요청 DTO
 */
@Getter
@NoArgsConstructor
public class UserSettingsRegisterRequestDto {

    @Schema(description = "위치 기반 알림 사용 여부", example = "true")
    private Boolean locationAlertEnabled;

    @Schema(description = "푸시 알림 사용 여부", example = "false")
    private Boolean pushAlertEnabled;

    @Schema(description = "장소 기본 반경(m)", example = "150")
    private Integer radiusM;
}
