package com.timingnote.api.domain.recommend.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * RECO-01 추천 목록 조회 요청 DTO.
 */
@Getter
@Setter
@NoArgsConstructor
public class RecommendListRequestDto {

    @NotNull
    @Schema(description = "현재 위도", example = "37.5172")
    private Double latitude;

    @NotNull
    @Schema(description = "현재 경도", example = "127.0473")
    private Double longitude;

    @Schema(description = "탐색 반경(m), 기본 300", example = "300")
    private Integer radiusM;

    @NotNull
    @Schema(description = "추천 트리거", example = "HOME_ENTER", allowableValues = {"HOME_ENTER", "MANUAL_REFRESH", "LOCATION_CHANGE"})
    private String triggerType;

    @Schema(description = "이동 방향(iOS CLLocation.course, degree)", example = "123.5")
    private Double course;
}
