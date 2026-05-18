package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.infra.client.ai.AiPlaceType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * 카카오 검색 결과로 PlaceType을 결정한다.
 *
 * <p>결정 알고리즘 (2026-05-12 문서: 4-2 / 4-3 / 4-7 사용자 회복성 원칙):
 * <ol>
 *   <li>결과 0건 → MEMO (null 반환)</li>
 *   <li>일반명사 사전 매칭({@link PlaceTextNormalizer}) → GENERIC 강제 (결과 수 무관)</li>
 *   <li>정규화한 장소명이 카카오 후보명과 완전 일치 → SPECIFIC</li>
 *   <li>그 외 검색 결과 존재 → GENERIC</li>
 * </ol>
 *
 * <p>의도적으로 카테고리 분포 분석·브랜드 추론·부속 시설 단어 판정을 적용하지 않는다.
 * <ul>
 *   <li>"스타" 같은 모호 입력에 시스템이 메이저 카테고리만 추정해 좁히면 사용자 동작 예측 불가</li>
 *   <li>확실한 exact match만 SPECIFIC으로 승격하고, 애매한 결과는 GENERIC 후보 풀로 보존</li>
 *   <li>동음이의어("약국이라는 음식점")는 발생 확률 극히 낮고, geofence 활성 후보 결정 단계에서
 *       거리 기준으로 자연 거름</li>
 * </ul>
 *
 * <p>2026-05-13 통일: 입력 타입을 {@link PlaceSearchItemResponse}로 일원화 — FE 검색창 캐시와
 * 같은 DTO를 다루므로 raw KakaoDocument 의존 제거.
 */
@Slf4j
@Component
public class PlaceTypeResolver {

    /**
     * 분류 결과. placeType이 null이면 매칭 실패(MEMO 처리).
     * items는 카카오 응답 순서를 그대로 전달 (필터링 없음).
     */
    public record Result(AiPlaceType placeType, List<PlaceSearchItemResponse> items) {
        public static Result memo() {
            return new Result(null, Collections.emptyList());
        }
    }

    public Result resolve(String placeText, List<PlaceSearchItemResponse> items) {
        if (items == null || items.isEmpty()) {
            log.info("[PLACE_TYPE] MEMO — 검색 결과 0건 (placeText='{}')", placeText);
            return Result.memo();
        }

        // 1. 일반명사 사전 매칭 → GENERIC 강제
        if (PlaceTextNormalizer.isGenericKeyword(placeText)) {
            log.info("[PLACE_TYPE] GENERIC 강제 — 사전 일반명사 (placeText='{}', count={})",
                    placeText, items.size());
            return new Result(AiPlaceType.GENERIC, items);
        }

        // 2. 정규화 완전 일치 후보가 있으면 SPECIFIC 확정.
        Optional<PlaceSearchItemResponse> exactMatch = findNormalizedExactMatch(placeText, items);
        if (exactMatch.isPresent()) {
            PlaceSearchItemResponse matched = exactMatch.get();
            log.info("[PLACE_TYPE] SPECIFIC — 장소명 정규화 완전 일치 (placeText='{}', matched='{}', count={})",
                    placeText, matched.getPlaceName(), items.size());
            return new Result(AiPlaceType.SPECIFIC, List.of(matched));
        }

        // 3. 후보는 있지만 exact match가 없으면 기존 알림 효율을 유지하기 위해 GENERIC 후보 풀로 둔다.
        log.info("[PLACE_TYPE] GENERIC — exact match 없음 (placeText='{}', count={})",
                placeText, items.size());
        return new Result(AiPlaceType.GENERIC, items);
    }

    private Optional<PlaceSearchItemResponse> findNormalizedExactMatch(
            String placeText,
            List<PlaceSearchItemResponse> items
    ) {
        String normalizedPlaceText = normalizeForExactMatch(placeText);
        if (normalizedPlaceText.isEmpty()) {
            return Optional.empty();
        }
        return items.stream()
                .filter(item -> normalizedPlaceText.equals(normalizeForExactMatch(item.getPlaceName())))
                .findFirst();
    }

    private static String normalizeForExactMatch(String value) {
        if (value == null) {
            return "";
        }
        String normalized = Normalizer.normalize(value.trim(), Normalizer.Form.NFKC)
                .toLowerCase(Locale.ROOT)
                .replaceAll("\\s+", "")
                .replaceAll("[^\\p{IsHangul}a-z0-9]", "");
        return removeBranchSuffix(normalized);
    }

    private static String removeBranchSuffix(String value) {
        return value.replaceAll("(지점|본점|branch|店)$", "")
                .replaceAll("(?<!서|매)점$", "");
    }
}
