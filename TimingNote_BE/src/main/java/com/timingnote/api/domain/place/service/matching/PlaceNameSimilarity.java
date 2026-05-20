package com.timingnote.api.domain.place.service.matching;

import java.util.HashSet;
import java.util.Set;

/**
 * 장소명 유사도 계산 — 카카오 ↔ 구글 매칭 시 좌표만으론 부족한 케이스 보강.
 *
 * 알고리즘: character bigram Jaccard.
 * - 토큰 분리(공백) 방식은 한국어 합성어/조사에 약해 character n-gram 채택.
 * - 정규화 단계에서 공백/지점 표기/특수문자 제거 후 2-gram 셋 추출.
 *
 * 예시:
 *   "스타벅스 서면점" vs "스타벅스 부산서면점" → 0.50 (통과)
 *   "서면약국"      vs "서면 새약국"          → 0.40 (보더라인)
 *   "이마트 서면"   vs "스타벅스 서면점"      → 0.10 (차단)
 */
public final class PlaceNameSimilarity {

    private PlaceNameSimilarity() {}

    /** 매칭 통과 임계값 — 운영 모니터링 후 조정. */
    public static final double DEFAULT_MIN_SIMILARITY = 0.4;

    /**
     * 두 장소명의 character bigram Jaccard 유사도. 0.0(완전 불일치) ~ 1.0(완전 일치).
     */
    public static double similarity(String a, String b) {
        if (a == null || b == null) return 0.0;
        String na = normalize(a);
        String nb = normalize(b);
        if (na.isEmpty() || nb.isEmpty()) return 0.0;
        if (na.length() < 2 || nb.length() < 2) {
            return na.equals(nb) ? 1.0 : 0.0;
        }
        Set<String> bigramsA = bigrams(na);
        Set<String> bigramsB = bigrams(nb);
        Set<String> intersection = new HashSet<>(bigramsA);
        intersection.retainAll(bigramsB);
        Set<String> union = new HashSet<>(bigramsA);
        union.addAll(bigramsB);
        return union.isEmpty() ? 0.0
                : (double) intersection.size() / union.size();
    }

    /** 임계값 이상이면 매칭 통과로 판단. */
    public static boolean isMatch(String a, String b, double minSimilarity) {
        return similarity(a, b) >= minSimilarity;
    }

    /**
     * 정규화: lowercase + 공백/특수문자 제거 + 지점 접미사 제거.
     * 한글/영문/숫자만 보존.
     */
    private static String normalize(String s) {
        return s.toLowerCase()
                .replaceAll("\\s+", "")
                .replaceAll("(점|지점|본점|店|branch)$", "")
                .replaceAll("\\d+호점$", "")
                .replaceAll("[^가-힣a-z0-9]", "");
    }

    private static Set<String> bigrams(String s) {
        Set<String> result = new HashSet<>(s.length());
        for (int i = 0; i < s.length() - 1; i++) {
            result.add(s.substring(i, i + 2));
        }
        return result;
    }
}
