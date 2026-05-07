package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "Todo 생성 요청")
public class TodoCreateRequest {

    @NotBlank
    @Size(max = 2000)
    @Schema(description = "메모 원문", example = "내일 오후 3시에 홈플러스 서면점 가서 우유 사기")
    private String content;

    @NotBlank
    @Pattern(regexp = "TEXT|VOICE|IMAGE|LINK")
    @Schema(description = "입력 유형", allowableValues = {"TEXT", "VOICE", "IMAGE", "LINK"}, example = "TEXT")
    private String inputType;

    @Schema(description = "메모 입력 시 사용자 위도 (선택, 없으면 Kakao 검색 정확도 낮아짐)", example = "35.1531")
    private Double latitude;

    @Schema(description = "메모 입력 시 사용자 경도 (선택)", example = "129.0585")
    private Double longitude;

    @Schema(description = "이동 방향 (iOS CLLocation.course, degree, 선택)", example = "180.0")
    private Double course;

    @Schema(description = "위치 측정 시각 (ISO-8601, 선택)", example = "2026-05-07T10:30:00+09:00")
    private OffsetDateTime occurredAt;
}
