package com.timingnote.api.infra.client.kakao;

import com.timingnote.api.infra.client.kakao.dto.KakaoReverseGeocodeResponse;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.service.annotation.GetExchange;
import org.springframework.web.service.annotation.HttpExchange;
import reactor.core.publisher.Mono;

/**
 * Kakao Local Geo API 클라이언트 (좌표 ↔ 주소 변환).
 *
 * KakaoLocalClient(/v2/local/search)와 base path가 달라서 별도 인터페이스로 분리한다.
 */
@HttpExchange("/v2/local/geo")
public interface KakaoGeoClient {

    /**
     * 좌표 → 주소(도로명/지번) 역지오코딩.
     * @param x 경도 (longitude)
     * @param y 위도 (latitude)
     */
    @GetExchange("/coord2address.json")
    Mono<KakaoReverseGeocodeResponse> reverseGeocode(
            @RequestParam("x") String x,
            @RequestParam("y") String y
    );
}
