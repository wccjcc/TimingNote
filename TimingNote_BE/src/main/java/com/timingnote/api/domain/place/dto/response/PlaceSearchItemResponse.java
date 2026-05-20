package com.timingnote.api.domain.place.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;
import lombok.Builder;
import lombok.Getter;

/**
 * 장소 검색 단건 응답.
 *
 * Kakao Local API의 document를 FE 친화적 camelCase로 정규화한 형태.
 * - 좌표 x/y(문자열) → latitude/longitude(double) 변환
 * - distance(문자열) → distanceMeter(Integer, 미터) 변환. 거리순 정렬 미요청 시 null.
 *
 * snake_case 그대로 전달하지 않는 이유: BE 응답 컨벤션 일관성 + FE 모델 변경 0
 * (FE의 KakaoPlaceItem.fromJson은 어차피 응답 필드명을 명시적으로 매핑하므로 BE에서 camelCase로
 * 정리해도 동일 일감으로 처리 가능).
 */
@Getter
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class PlaceSearchItemResponse {

    private final String id;
    private final String placeName;
    private final Double latitude;
    private final Double longitude;
    private final String categoryName;        // 전체 경로 ("음식점 > 한식 > 국밥"). 내부 Place 저장에 사용
    private final String categoryGroupCode;
    private final String categoryGroupName;
    private final String phone;
    private final String addressName;
    private final String roadAddressName;
    private final String placeUrl;
    private final Integer distanceMeter;

    public static PlaceSearchItemResponse from(KakaoDocument doc) {
        return PlaceSearchItemResponse.builder()
                .id(doc.getId())
                .placeName(doc.getPlaceName())
                .latitude(parseDoubleOrNull(doc.getY()))
                .longitude(parseDoubleOrNull(doc.getX()))
                .categoryName(doc.getCategoryName())
                .categoryGroupCode(doc.getCategoryGroupCode())
                .categoryGroupName(doc.getCategoryGroupName())
                .phone(emptyToNull(doc.getPhone()))
                .addressName(doc.getAddressName())
                .roadAddressName(doc.getRoadAddressName())
                .placeUrl(doc.getPlaceUrl())
                .distanceMeter(parseIntOrNull(doc.getDistance()))
                .build();
    }

    private static Double parseDoubleOrNull(String s) {
        if (s == null || s.isBlank()) return null;
        try { return Double.parseDouble(s); } catch (NumberFormatException e) { return null; }
    }

    private static Integer parseIntOrNull(String s) {
        if (s == null || s.isBlank()) return null;
        try { return Integer.parseInt(s); } catch (NumberFormatException e) { return null; }
    }

    private static String emptyToNull(String s) {
        return (s == null || s.isBlank()) ? null : s;
    }
}
