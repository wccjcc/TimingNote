package com.timingnote.api.domain.notification.dto.response;

import com.timingnote.api.domain.notification.entity.UserNotification;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

/**
 * 알림 이력 단건 응답 DTO.
 */
@Getter
@Builder
@Schema(description = "알림 이력 단건")
public class NotificationHistoryItemResponseDto {

    @Schema(description = "알림 PK")
    private Long id;

    @Schema(description = "유저 ID")
    private Long userId;

    @Schema(description = "연결된 Todo ID")
    private Long todoId;

    @Schema(description = "알림 유형 (SPECIFIC | GENERIC)")
    private String notificationType;

    @Schema(description = "알림 상태 (SENT | OPENED | FAILED)")
    private String status;

    @Schema(description = "알림 제목")
    private String title;

    @Schema(description = "알림 본문")
    private String body;

    @Schema(description = "생성 시각 (UTC, ISO 8601)")
    private OffsetDateTime createdAt;

    @Schema(description = "읽음 시각 (UTC, ISO 8601)")
    private OffsetDateTime openedAt;

    public static NotificationHistoryItemResponseDto from(UserNotification notification) {
        return NotificationHistoryItemResponseDto.builder()
                .id(notification.getId())
                .userId(notification.getUserId())
                .todoId(notification.getTodoId())
                .notificationType(notification.getNotificationType().name())
                .status(notification.getStatus().name())
                .title(notification.getTitle())
                .body(notification.getBody())
                .createdAt(notification.getCreatedAt())
                .openedAt(notification.getOpenedAt())
                .build();
    }
}
