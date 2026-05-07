package com.timingnote.api.domain.notification.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

/**
 * NOTI-02 알림 액션 응답 DTO.
 */
@Getter
@Builder
@Schema(description = "알림 액션 처리 결과")
public class NotificationActionResponseDto {

    @Schema(description = "처리된 액션 타입")
    private String actionType;

    @Schema(description = "COMPLETE 처리 시 Todo 상태")
    private String todoStatus;

    @Schema(description = "SNOOZE 처리 시 해제 시각(UTC, ISO 8601)")
    private OffsetDateTime snoozedUntil;
}

