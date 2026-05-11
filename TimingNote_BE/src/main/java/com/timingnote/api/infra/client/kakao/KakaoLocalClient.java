package com.timingnote.api.infra.client.kakao;

import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.service.annotation.GetExchange;
import org.springframework.web.service.annotation.HttpExchange;
import reactor.core.publisher.Mono;

@HttpExchange("/v2/local/search")
public interface KakaoLocalClient {

    /**
     * SPECIFIC 장소 검색 — 이름으로 검색 + 사용자 좌표로 정확도 향상
     * x, y: 선택(null 가능). 없으면 전국 accuracy 정렬.
     */
    @GetExchange("/keyword.json")
    Mono<KakaoLocalSearchResponse> searchByKeyword(
            @RequestParam("query") String query,
            @RequestParam(value = "x", required = false) String x,
            @RequestParam(value = "y", required = false) String y,
            @RequestParam("size") int size
    );

    /**
     * GENERIC 키워드 검색 — 반경 내 키워드 검색 + 거리순.
     * x, y, radius 필수. placeText 그대로 query 로 전달한다.
     */
    @GetExchange("/keyword.json")
    Mono<KakaoLocalSearchResponse> searchByKeywordNearby(
            @RequestParam("query") String query,
            @RequestParam("x") String x,
            @RequestParam("y") String y,
            @RequestParam("radius") int radius,
            @RequestParam("size") int size,
            @RequestParam("sort") String sort
    );
}
