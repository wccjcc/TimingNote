package com.timingnote.api.domain.place.service;

import java.util.Set;

/**
 * placeText의 일반명사 여부 판정기.
 *
 * <p>설계 결정 (2026-05-12 문서: 4-3):
 * <ul>
 *   <li>의심 여지 없는 일반명사만 등재 (마트=이마트 약칭 가능, 다이소=브랜드 등은 제외)</li>
 *   <li>kakaoCategory 메타는 사용 안 함 — 카카오 응답이 자체적으로 분류 정보 제공</li>
 *   <li>단순 {@link Set} 매칭으로 시작. 항목 50개 초과 시 DB 테이블 검토.</li>
 * </ul>
 *
 * <p>일반명사로 판정되면 {@code PlaceType.GENERIC}이 강제됨 — 우연히 검색 결과 1건만 매칭돼도
 * 사용자 의도("아무 약국이나")가 보존됨.
 */
public final class PlaceTextNormalizer {

    private static final Set<String> GENERIC_KEYWORDS = Set.of(
            "약국",
            "편의점",
            "카페",
            "병원",
            "음식점",
            "은행",
            "주유소",
            "세탁소",
            "미용실",
            "PC방",
            "노래방",
            "헬스장",
            "학원"
    );

    private PlaceTextNormalizer() {
        // 정적 사전. 인스턴스 생성 차단.
    }

    /**
     * placeText가 사전 등재된 일반명사인지 판정.
     * trim 후 정확 일치만 매칭 (변형/조사 처리 없음 — AI가 깨끗한 placeText로 추출하는 전제).
     */
    public static boolean isGenericKeyword(String placeText) {
        if (placeText == null) return false;
        return GENERIC_KEYWORDS.contains(placeText.trim());
    }
}
