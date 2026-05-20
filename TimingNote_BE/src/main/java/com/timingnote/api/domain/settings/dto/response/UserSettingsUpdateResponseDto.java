package com.timingnote.api.domain.settings.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

/**
 * SETTINGS-02 설정 수정 응답 DTO
 */
@Getter
@Builder
public class UserSettingsUpdateResponseDto {

    @Schema(description = "변경 후 위치 기반 알림 사용 여부", example = "true")
    private Boolean locationAlertEnabled;

    @Schema(description = "변경 후 푸시 알림 사용 여부", example = "false")
    private Boolean pushAlertEnabled;

    @Schema(description = "변경 후 장소 기본 반경(m)", example = "150")
    private Integer radiusM;

    @Schema(description = "수정 시각 (ISO 8601)", example = "2026-04-19T11:00:00Z")
    private String updatedAt;
}
