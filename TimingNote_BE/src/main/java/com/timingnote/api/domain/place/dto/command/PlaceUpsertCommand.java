package com.timingnote.api.domain.place.dto.command;

/**
 * FE에서 직접 선택한 Kakao 장소 정보를 PlaceService로 전달하는 커맨드 객체.
 * places 테이블 upsert에 필요한 필드만 담는다.
 */
public record PlaceUpsertCommand(
        String kakaoPlaceId,
        String placeName,
        String addressName,
        String roadAddressName,
        String categoryGroupCode,
        String categoryGroupName,
        String phone,
        String placeUrl,
        Double longitude,
        Double latitude
) {
    public static PlaceUpsertCommand of(
            String kakaoPlaceId, String placeName,
            String addressName, String roadAddressName,
            String categoryGroupCode, String categoryGroupName,
            String phone, String placeUrl,
            Double longitude, Double latitude) {
        return new PlaceUpsertCommand(kakaoPlaceId, placeName,
                addressName, roadAddressName,
                categoryGroupCode, categoryGroupName,
                phone, placeUrl, longitude, latitude);
    }
}
