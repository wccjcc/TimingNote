package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;

import java.util.List;
import java.util.Optional;

public interface PlaceService {

    /**
     * SPECIFIC: placeText + 사용자 좌표 → Kakao keyword 검색 → Google 영업시간 보강 → Place 반환
     * lat/lon null 허용 (없으면 전국 검색, 정확도 낮아짐)
     */
    Optional<Place> resolveSpecificPlace(String placeText, Double latitude, Double longitude);

    /**
     * GENERIC: placeText + 사용자 좌표 → 카테고리 or 키워드 검색 → 반경 내 후보 목록 반환
     * lat/lon 필수 (없으면 빈 리스트 반환)
     */
    List<Place> resolveGenericCandidates(String placeText, Double latitude, Double longitude);

    /**
     * FE가 직접 선택하거나 지도 마커로 찍은 장소를 places 테이블에 저장.
     * - kakaoPlaceId 있음 (Kakao 검색 결과): externalPlaceId로 dedup 후 저장
     * - kakaoPlaceId 없음 (지도 마커 핀): 항상 신규 저장 (dedup 없음)
     * Google 영업시간 보강은 하지 않는다 (AI structuring 경로에서만 수행).
     */
    Place saveUserSelectedPlace(PlaceUpsertCommand command);
}
