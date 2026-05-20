package com.timingnote.api.domain.place.service.matching;

import java.util.Map;
import java.util.Set;

/**
 * 카카오 categoryGroupCode와 구글 Places primaryType의 호환성 검증.
 *
 * 좌표 + 이름 유사도만으로는 같은 위치에 있는 다른 업종(예: 같은 건물의 약국과 카페)이
 * 잘못 매칭될 수 있다. 양쪽 카테고리 메타가 모두 있을 때 cross-check를 통해 차단.
 *
 * 매핑 출처:
 * - Kakao: category_group_code 공식 표 (CS2/MT1/CE7/FD6/OL7/BK9/HP8/PM9/PK6/PO3)
 * - Google: https://developers.google.com/maps/documentation/places/web-service/place-types (Table A)
 */
public final class KakaoGoogleCategoryMapping {

    private KakaoGoogleCategoryMapping() {}

    private static final Map<String, Set<String>> ALLOWED_GOOGLE_TYPES = Map.ofEntries(
            // 편의점
            Map.entry("CS2", Set.of("convenience_store")),
            // 대형마트 / 백화점
            Map.entry("MT1", Set.of(
                    "supermarket", "grocery_store", "hypermarket",
                    "department_store", "discount_store", "warehouse_store")),
            // 카페
            Map.entry("CE7", Set.of("cafe", "coffee_shop", "bakery", "tea_house")),
            // 음식점
            Map.entry("FD6", Set.of(
                    "restaurant", "fast_food_restaurant", "meal_takeaway",
                    "meal_delivery", "bar", "bar_and_grill", "japanese_restaurant",
                    "chinese_restaurant", "korean_restaurant", "italian_restaurant",
                    "pizza_restaurant", "hamburger_restaurant", "sandwich_shop",
                    "seafood_restaurant", "steak_house", "buffet_restaurant")),
            // 주유소 / 충전소
            Map.entry("OL7", Set.of("gas_station", "electric_vehicle_charging_station")),
            // 은행
            Map.entry("BK9", Set.of("bank", "atm")),
            // 병원 / 의원
            Map.entry("HP8", Set.of(
                    "hospital", "doctor", "dental_clinic", "clinic",
                    "medical_center", "physiotherapist", "veterinary_care")),
            // 약국
            Map.entry("PM9", Set.of("pharmacy", "drugstore")),
            // 주차장
            Map.entry("PK6", Set.of("parking")),
            // 공공기관
            Map.entry("PO3", Set.of(
                    "city_hall", "courthouse", "embassy", "post_office",
                    "local_government_office", "government_office", "library")));

    /**
     * 두 카테고리가 호환되는지 검증.
     * - 어느 한쪽이라도 정보가 없으면 통과 (검증 불가능 → 보수적으로 통과)
     * - 매핑 테이블에 없는 kakaoCode면 통과 (도메인 외 카테고리 → 차단할 근거 없음)
     * - 매핑이 있는데 googlePrimaryType이 허용 set에 없으면 차단
     */
    public static boolean isCompatible(String kakaoCode, String googlePrimaryType) {
        // [enrichment 비활성화] Google enrichment 흐름 전체가 주석 처리되어 호출되지 않지만,
        // 클래스/메서드 보존 차원에서 본문도 명시적 no-op 처리. 추후 영업시간 보강 재도입 시
        // 아래 원본 본문 주석 해제로 1회 복원 가능.
        return true;
        /*
        if (kakaoCode == null || googlePrimaryType == null) return true;
        Set<String> allowed = ALLOWED_GOOGLE_TYPES.get(kakaoCode);
        if (allowed == null) return true;
        return allowed.contains(googlePrimaryType);
        */
    }
}
