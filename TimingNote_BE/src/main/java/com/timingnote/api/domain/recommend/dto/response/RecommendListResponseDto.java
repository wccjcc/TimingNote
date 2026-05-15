package com.timingnote.api.domain.recommend.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * RECO-01 추천 목록 조회 응답 DTO.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecommendListResponseDto {

    @Schema(description = "현재 위치 표시 라벨", example = "광주 서구 치평동")
    private String currentLocationLabel;

    @Schema(description = "추천 항목 목록")
    private List<RecommendItemResponseDto> items;

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RecommendItemResponseDto {

        @Schema(description = "추천 순위", example = "1")
        private Integer rank;

        @Schema(description = "할 일 ID", example = "42")
        private Long todoId;

        @Schema(description = "할 일 요약 문구", example = "다이소에서 멀티탭 사기")
        private String summaryText;

        @Schema(description = "할 일 카테고리", example = "ACQUIRE")
        private String category;

        @Schema(description = "장소 라벨", example = "다이소")
        private String resolvedPlaceLabel;

        @Schema(description = "장소명", example = "다이소 강남점")
        private String placeName;

        @Schema(description = "장소 위도", example = "37.5010")
        private Double latitude;

        @Schema(description = "장소 경도", example = "127.0260")
        private Double longitude;

        @Schema(description = "현재 위치 기준 거리(m)", example = "350")
        private Integer distanceM;

        @Schema(description = "추천 점수", example = "0.91")
        private Double score;
    }
}
