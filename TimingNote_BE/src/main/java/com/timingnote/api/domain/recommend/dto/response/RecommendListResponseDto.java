package com.timingnote.api.domain.recommend.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecommendListResponseDto {

    @Schema(description = "현재 좌표를 기준으로 만든 현재 위치 라벨", example = "광주광역시 치평동")
    private String currentLocationLabel;

    @Schema(description = "장소 기준 그룹 추천 목록")
    private List<RecommendGroupResponseDto> items;

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RecommendGroupResponseDto {

        @Schema(description = "추천 순위", example = "1")
        private Integer rank;

        @Schema(description = "장소 그룹 ID(현재는 placeId 사용)", example = "101")
        private Long groupId;

        @Schema(description = "장소명", example = "이마트")
        private String placeName;

        @Schema(description = "장소 위도", example = "35.1548")
        private Double latitude;

        @Schema(description = "장소 경도", example = "126.8512")
        private Double longitude;

        @Schema(description = "현재 위치와의 거리(m)", example = "210")
        private Integer distanceM;

        @Schema(description = "해당 장소에 연결된 할일 개수", example = "2")
        private Integer todoCount;

        @Schema(description = "해당 장소에 연결된 할일 목록")
        private List<RecommendTodoResponseDto> todos;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RecommendTodoResponseDto {

        @Schema(description = "할일 ID", example = "42")
        private Long todoId;

        @Schema(description = "할일 요약/내용", example = "고양이 사료 사기")
        private String summaryText;

        @Schema(description = "카테고리", example = "ACQUIRE")
        private String category;

        @Schema(description = "해결된 장소 라벨", example = "이마트")
        private String resolvedPlaceLabel;
    }
}
