package com.timingnote.api.domain.notification.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * NOTI-03 알림 읽음 처리 요청 DTO.
 */
@Getter
@NoArgsConstructor
@Schema(description = "알림 읽음 처리 요청")
public class NotificationReadUpdateRequestDto {

    @NotNull
    @AssertTrue
    @Schema(description = "읽음 처리 여부(항상 true)", example = "true")
    private Boolean isRead;
}

