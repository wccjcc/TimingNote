package com.timingnote.api.infra.client.kakao.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Kakao Local API의 좌표→주소 변환(coord2address) 응답.
 *
 * 응답 documents는 보통 0~1개. 좌표가 행정구역 경계에 걸린 일부 케이스에서만 2개 이상 반환.
 * 첫 document의 road_address(도로명) 우선, 없으면 address(지번)을 사용한다.
 */
@Getter
@NoArgsConstructor
public class KakaoReverseGeocodeResponse {

    private List<Document> documents;

    @Getter
    @NoArgsConstructor
    public static class Document {

        @JsonProperty("road_address")
        private AddressNode roadAddress;

        @JsonProperty("address")
        private AddressNode address;
    }

    @Getter
    @NoArgsConstructor
    public static class AddressNode {

        @JsonProperty("address_name")
        private String addressName;
    }
}
