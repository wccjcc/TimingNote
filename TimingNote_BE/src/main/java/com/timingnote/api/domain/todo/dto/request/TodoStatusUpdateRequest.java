package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "할 일 상태 변경 요청")
public class TodoStatusUpdateRequest {

    @NotBlank
    @Pattern(regexp = "ACTIVE|DONE", message = "status는 ACTIVE 또는 DONE이어야 합니다")
    @Schema(description = "변경할 상태", allowableValues = {"ACTIVE", "DONE"})
    private String status;

    @Schema(description = "사용자 현재 위도 — 슬롯 재계산 정확도 향상 (선택)")
    private Double latitude;

    @Schema(description = "사용자 현재 경도 (선택)")
    private Double longitude;

    @Schema(description = "이동 방향 (iOS CLLocation.course, degree, 선택)")
    private Double course;

    @Schema(description = "위치 측정 시각 (ISO-8601, 선택)")
    private OffsetDateTime occurredAt;
}
