package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "알림 설정 변경 요청")
public class TodoAlertUpdateRequest {

    @NotNull
    @Schema(description = "알림 활성화 여부")
    private Boolean alertEnabled;

    @Schema(description = "사용자 현재 위도 — 슬롯 재계산 정확도 향상 (선택)")
    private Double latitude;

    @Schema(description = "사용자 현재 경도 (선택)")
    private Double longitude;

    @Schema(description = "이동 방향 (iOS CLLocation.course, degree, 선택)")
    private Double course;

    @Schema(description = "위치 측정 시각 (ISO-8601, 선택)")
    private OffsetDateTime occurredAt;
}
