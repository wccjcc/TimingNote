package com.timingnote.api.domain.notification.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
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

    @Schema(description = "현재 위치 위도(없으면 null)", example = "35.1595454")
    private BigDecimal latitude;

    @Schema(description = "현재 위치 경도(없으면 null)", example = "126.8526012")
    private BigDecimal longitude;

    @Schema(description = "현재 이동 방향(course, degree, 없으면 null)", example = "180.0")
    private BigDecimal course;
}
