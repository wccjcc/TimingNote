package com.timingnote.api.domain.place.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 좌표 → 주소 변환 응답. address는 도로명 우선, 없으면 지번.
 * 좌표가 해상/사막 등 주소 매칭 불가능한 경우 null.
 */
@Getter
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ReverseGeocodeResponse {
    private final String address;
}
