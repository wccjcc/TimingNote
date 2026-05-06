package com.timingnote.api.domain.notification.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * NOTI-02 알림 액션 요청 DTO.
 */
@Getter
@NoArgsConstructor
@Schema(description = "알림 액션 요청")
public class NotificationActionRequestDto {

    @NotNull
    @Schema(description = "액션 타입", allowableValues = {"OPEN", "COMPLETE", "SNOOZE", "DISMISS"})
    private NotificationActionType actionType;

    @Schema(description = "SNOOZE일 때 지연 분")
    private Integer snoozeMinutes;
}

