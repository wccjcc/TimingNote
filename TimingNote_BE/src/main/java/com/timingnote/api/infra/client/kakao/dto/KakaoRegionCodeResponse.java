package com.timingnote.api.infra.client.kakao.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class KakaoRegionCodeResponse {

    private List<Document> documents;

    @Getter
    @NoArgsConstructor
    public static class Document {

        @JsonProperty("region_type")
        private String regionType; // H: 행정동, B: 법정동

        @JsonProperty("address_name")
        private String addressName;

        @JsonProperty("region_1depth_name")
        private String region1DepthName; // 시/도

        @JsonProperty("region_2depth_name")
        private String region2DepthName; // 시/군/구

        @JsonProperty("region_3depth_name")
        private String region3DepthName; // 동/읍/면

        @JsonProperty("region_4depth_name")
        private String region4DepthName; // 리
    }
}
