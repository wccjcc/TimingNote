package com.timingnote.api.domain.fcm_test.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class FcmGeofenceTestSendRequestDto {

    @Schema(description = "FCM registration token", example = "fCm_token_string...")
    @NotBlank(message = "token은 필수입니다.")
    private String token;

    @Schema(description = "푸시 payload의 todoId", example = "101")
    @NotNull(message = "todoId는 필수입니다.")
    @Positive(message = "todoId는 양수여야 합니다.")
    private Long todoId;

    @Schema(description = "푸시 payload의 notificationId", example = "202")
    @NotNull(message = "notificationId는 필수입니다.")
    @Positive(message = "notificationId는 양수여야 합니다.")
    private Long notificationId;

    @Schema(description = "장소명(제목 생성용)", example = "삼성역", nullable = true)
    private String placeName;

    @Schema(description = "할 일 본문", example = "우산 챙기기", nullable = true)
    private String todoContent;
}
