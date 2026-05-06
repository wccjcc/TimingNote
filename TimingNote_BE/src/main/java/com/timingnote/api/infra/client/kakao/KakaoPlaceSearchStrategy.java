package com.timingnote.api.infra.client.kakao;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * placeText → Kakao 검색 전략 결정 유틸
 *
 * 카테고리명이면 category.json (더 정확, 노이즈 없음)
 * 브랜드명/기타이면 keyword.json + 반경 (fallback)
 */
public class KakaoPlaceSearchStrategy {

    public record Decision(boolean useCategory, String categoryGroupCode) {}

    // 포함 키워드 → category_group_code (순서 중요: 긴 것/구체적인 것부터)
    private static final Map<String, String> KEYWORD_TO_CODE = new LinkedHashMap<>() {{
        // 편의점 브랜드 — "이마트24"가 "이마트" 보다 먼저 와야 MT1 오매칭 방지
        put("GS25",      "CS2");
        put("CU",        "CS2");
        put("세븐일레븐","CS2");
        put("이마트24",  "CS2");
        put("미니스톱",  "CS2");
        put("씨유",      "CS2");
        put("편의점",    "CS2");
        // 대형마트 브랜드
        put("이마트",    "MT1");
        put("홈플러스",  "MT1");
        put("롯데마트",  "MT1");
        put("코스트코",  "MT1");
        put("대형마트",  "MT1");
        put("마트",      "MT1");
        // 카페 브랜드
        put("스타벅스",  "CE7");
        put("투썸플레이스","CE7");
        put("이디야",    "CE7");
        put("메가커피",  "CE7");
        put("컴포즈",    "CE7");
        put("빽다방",    "CE7");
        put("할리스",    "CE7");
        put("카페",      "CE7");
        put("커피",      "CE7");
        // 음식점 브랜드
        put("맥도날드",  "FD6");
        put("버거킹",    "FD6");
        put("롯데리아",  "FD6");
        put("KFC",       "FD6");
        put("서브웨이",  "FD6");
        put("음식점",    "FD6");
        put("식당",      "FD6");
        put("맛집",      "FD6");
        // 주유 / 충전
        put("주유소",    "OL7");
        put("충전소",    "OL7");
        // 금융
        put("은행",      "BK9");
        // 의료
        put("병원",      "HP8");
        put("약국",      "PM9");
        // 기타
        put("주차장",    "PK6");
        put("공공기관",  "PO3");
    }};

    public static Decision decide(String placeText) {
        if (placeText == null || placeText.isBlank()) {
            return new Decision(false, null);
        }
        for (Map.Entry<String, String> entry : KEYWORD_TO_CODE.entrySet()) {
            if (placeText.contains(entry.getKey())) {
                return new Decision(true, entry.getValue());
            }
        }
        return new Decision(false, null);
    }
}
