package com.timingnote.api.domain.user.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "내 장소 등록 요청")
public class UserPlaceCreateRequest {

    @NotBlank
    @Schema(description = "장소 별칭 (예: 집, 회사, 부모님댁)", example = "집")
    private String aliasName;

    @Schema(description = "카카오 장소 ID — 지도 마커 핀 등록 시 null", example = "26338954")
    private String kakaoPlaceId;

    @NotBlank
    @Schema(description = "장소명", example = "서울역")
    private String placeName;

    @Schema(description = "지번 주소")
    private String addressName;

    @Schema(description = "도로명 주소")
    private String roadAddressName;

    @Schema(description = "카카오 대분류 코드")
    private String categoryGroupCode;

    @Schema(description = "카카오 대분류 이름")
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
