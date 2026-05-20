package com.timingnote.api.infra.client.kakao;

import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.service.annotation.GetExchange;
import org.springframework.web.service.annotation.HttpExchange;
import reactor.core.publisher.Mono;

@HttpExchange("/v2/local/search")
public interface KakaoLocalClient {

    /**
     * 카카오 키워드 검색 — 좌표가 있으면 거리 가중치가 accuracy 정렬에 반영돼
     * 가까운 매장이 우선 (실측 검증 완료).
     *
     * <p>2026-05-13 통일: radius/sort 강제 호출(과거 {@code searchByKeywordNearby})은 제거.
     * 등록·후보 재계산 모두 좌표만 전달하는 단일 정책으로 통일한다.
     *
     * <p>2026-05-13 size 제거: 카카오 기본값 15(= max)이 항상 우리 수요와 일치하므로 미전송.
     * 캐시 키 단순화 + FE/BE 호출 시그니처 통일 효과.
     *
     * <p>x, y: 선택(null 가능). 없으면 전국 accuracy 정렬.
     */
    @GetExchange("/keyword.json")
    Mono<KakaoLocalSearchResponse> searchByKeyword(
            @RequestParam("query") String query,
            @RequestParam(value = "x", required = false) String x,
            @RequestParam(value = "y", required = false) String y
    );
}
