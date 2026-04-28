package com.timingnote.api.infra.client.kakao.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class KakaoDocument {

    private String id;

    @JsonProperty("place_name")
    private String placeName;

    @JsonProperty("address_name")
    private String addressName;

    @JsonProperty("road_address_name")
    private String roadAddressName;

    @JsonProperty("category_name")
    private String categoryName;

    @JsonProperty("category_group_code")
    private String categoryGroupCode; // "PM9", "CE7" 등 Kakao 대분류 코드

    @JsonProperty("category_group_name")
    private String categoryGroupName; // "약국", "카페" 등 대분류 이름

    private String phone;

    @JsonProperty("place_url")
    private String placeUrl;

    private String x; // 경도(longitude)
    private String y; // 위도(latitude)

    private String distance; // 거리순 정렬 시 미터 단위 (좌표 지정 시 채워짐)
}
