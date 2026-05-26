package com.timingnote.api.domain.place.service;

import java.util.Set;

/**
 * 장소 검색 관련 텍스트 정규화 유틸리티.
 */
public final class PlaceTextNormalizer {

    private static final Set<String> GENERIC_KEYWORDS = Set.of(
            "약국", "편의점", "카페", "병원", "음식점", "은행", "주유소",
            "세탁소", "미용실", "PC방", "노래방", "헬스장", "학원"
    );

    private PlaceTextNormalizer() {
    }

    /**
     * 입력된 텍스트가 포괄적 장소(Generic Place)를 나타내는 키워드인지 판정한다.
     * 
     * @param placeText 판정할 텍스트
     * @return 일반명사 키워드 세트에 포함되면 true
     */
    public static boolean isGenericKeyword(String placeText) {
        if (placeText == null) return false;
        return GENERIC_KEYWORDS.contains(placeText.trim());
    }
}
