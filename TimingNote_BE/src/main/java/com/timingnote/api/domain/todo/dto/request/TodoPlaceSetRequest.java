package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "Todo 장소 지정 요청 — FE가 Kakao 검색 결과를 그대로 전달")
public class TodoPlaceSetRequest {

    @NotBlank
    @Schema(description = "카카오 장소 ID", example = "26338954")
    private String kakaoPlaceId;

    @NotBlank
    @Schema(description = "장소명", example = "다이소 명동본점")
    private String placeName;

    @Schema(description = "지번 주소")
    private String addressName;

    @Schema(description = "도로명 주소")
    private String roadAddressName;

    @Schema(description = "카카오 대분류 코드 (예: MT1, CE7, PM9)")
    private String categoryGroupCode;

    @Schema(description = "카카오 대분류 이름 (예: 대형마트, 카페, 약국)")
    private String categoryGroupName;

    @Schema(description = "전화번호")
    private String phone;

    @Schema(description = "카카오 장소 상세 URL")
    private String placeUrl;

    @NotNull
    @Schema(description = "경도 (longitude)", example = "126.9827")
    private Double longitude;

    @NotNull
    @Schema(description = "위도 (latitude)", example = "37.5637")
    private Double latitude;
}
