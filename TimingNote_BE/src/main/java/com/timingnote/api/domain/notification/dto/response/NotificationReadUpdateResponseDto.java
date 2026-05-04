package com.timingnote.api.domain.notification.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

/**
 * NOTI-03 알림 읽음 처리 응답 DTO.
 */
@Getter
@Builder
@Schema(description = "알림 읽음 처리 결과")
public class NotificationReadUpdateResponseDto {

    @Schema(description = "알림 PK")
    private Long notificationId;

    @Schema(description = "읽음 처리 시각(UTC, ISO 8601)")
    private OffsetDateTime openedAt;
}

