package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Getter
@NoArgsConstructor
@Schema(description = "Todo 장소 지정 요청. userPlaceId(ALIAS) 또는 externalPlace(SPECIFIC) 중 하나만 포함해야 한다.")
public class TodoPlaceSetRequest {

    @Schema(description = "내 장소 ID — 내 장소 목록에서 선택 시 사용 (ALIAS)", example = "1")
    private Long userPlaceId;

    @Valid
    @Schema(description = "외부 장소 정보 — Kakao 키워드/주소 검색 또는 지도 마커 핀 선택 시 사용 (SPECIFIC)")
    private ExternalPlaceInfo externalPlace;

    @Schema(description = "사용자 현재 위도 — 슬롯 정확도 향상을 위해 선택적으로 전달", example = "37.5660")
    private Double latitude;

    @Schema(description = "사용자 현재 경도", example = "126.9815")
    private Double longitude;

    @Schema(description = "이동 방향 (iOS CLLocation.course, 선택)", example = "180.0")
    private Double course;

    @Schema(description = "위치 정보 수집 시각 (ISO-8601, 선택)", example = "2026-05-07T10:30:00+09:00")
    private OffsetDateTime occurredAt;


    @Getter
    @NoArgsConstructor
    @Schema(description = "외부 장소 상세 정보")
    public static class ExternalPlaceInfo {

        @Schema(description = "카카오 장소 ID (키워드 검색 결과만 존재, 주소 검색·마커 핀은 null)", example = "26338954")
        private String kakaoPlaceId;    // nullable — null 이면 새 Place 레코드 생성

        @NotBlank
        @Schema(description = "장소명", example = "스타벅스 을지로점")
        private String placeName;

        @NotNull
        @Schema(description = "위도", example = "37.5660")
        private Double latitude;

        @NotNull
        @Schema(description = "경도", example = "126.9815")
        private Double longitude;

        @Schema(description = "지번 주소")
        private String addressName;

        @Schema(description = "도로명 주소")
        private String roadAddressName;

        @Schema(description = "카카오 대분류 코드 (예: CE7, PM9)")
        private String categoryGroupCode;

        @Schema(description = "카카오 대분류 이름 (예: 카페, 약국)")
        private String categoryGroupName;

        @Schema(description = "전화번호")
        private String phone;

        @Schema(description = "카카오 장소 상세 URL")
        private String placeUrl;
    }
}
