package com.timingnote.api.domain.place.service;

import com.timingnote.api.infra.client.ai.AiPlaceType;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

/**
 * 카카오 검색 결과로 PlaceType을 결정한다.
 *
 * <p>결정 알고리즘 (2026-05-12 문서: 4-2 / 4-3 / 4-7 사용자 회복성 원칙):
 * <ol>
 *   <li>결과 0건 → MEMO (null 반환)</li>
 *   <li>일반명사 사전 매칭({@link PlaceTextNormalizer}) → GENERIC 강제 (결과 수 무관)</li>
 *   <li>결과 1건 → SPECIFIC, 2건+ → GENERIC</li>
 * </ol>
 *
 * <p>의도적으로 카테고리 분포 분석·placeText 필터링을 적용하지 않는다.
 * <ul>
 *   <li>"스타" 같은 모호 입력에 시스템이 메이저 카테고리만 추정해 좁히면 사용자 동작 예측 불가</li>
 *   <li>잘못된 결과는 사용자가 더 구체적 키워드로 재입력해 회복 — 자동 추정보다 직관적</li>
 *   <li>동음이의어("약국이라는 음식점")는 발생 확률 극히 낮고, geofence 활성 후보 결정 단계에서
 *       거리 기준으로 자연 거름</li>
 * </ul>
 */
@Slf4j
@Component
public class PlaceTypeResolver {

    /**
     * 분류 결과. placeType이 null이면 매칭 실패(MEMO 처리).
     * documents는 카카오 응답을 그대로 전달 (필터링 없음).
     */
    public record Result(AiPlaceType placeType, List<KakaoDocument> documents) {
        public static Result memo() {
            return new Result(null, Collections.emptyList());
        }
    }

    public Result resolve(String placeText, List<KakaoDocument> rawResults) {
        if (rawResults == null || rawResults.isEmpty()) {
            log.info("[PLACE_TYPE] MEMO — 검색 결과 0건 (placeText='{}')", placeText);
            return Result.memo();
        }

        // 1. 일반명사 사전 매칭 → GENERIC 강제
        if (PlaceTextNormalizer.isGenericKeyword(placeText)) {
            log.info("[PLACE_TYPE] GENERIC 강제 — 사전 일반명사 (placeText='{}', count={})",
                    placeText, rawResults.size());
            return new Result(AiPlaceType.GENERIC, rawResults);
        }

        // 2. 결과 수로 판정 — 1건 SPECIFIC, 다수 GENERIC
        AiPlaceType type = (rawResults.size() == 1) ? AiPlaceType.SPECIFIC : AiPlaceType.GENERIC;
        log.info("[PLACE_TYPE] {} — 결과 수 기반 (placeText='{}', count={})",
                type, placeText, rawResults.size());
        return new Result(type, rawResults);
    }
}
