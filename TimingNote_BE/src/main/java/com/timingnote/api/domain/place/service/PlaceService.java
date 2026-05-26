package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.entity.Place;

import java.util.List;

/**
 * 장소 도메인 서비스 인터페이스.
 * 장소 검색, 저장 및 동기화 로직을 정의한다.
 */
public interface PlaceService {

    /**
     * 키워드 기반 통합 검색을 수행하고 결과를 DB에 동기화(Upsert)한다.
     * 
     * @param placeText 검색 키워드
     * @param latitude  기준 위도
     * @param longitude 기준 경도
     * @return 검색 결과 DTO와 DB에 반영된 엔티티 리스트
     */
    SearchResult searchAndStoreAll(String placeText, Double latitude, Double longitude);

    /** 검색 결과 데이터 홀더 */
    record SearchResult(List<PlaceSearchItemResponse> searchItems, List<Place> storedPlaces) {
        public static SearchResult empty() {
            return new SearchResult(List.of(), List.of());
        }
        public boolean isEmpty() { return searchItems.isEmpty(); }
    }

    /**
     * 사용자 선택 장소(검색 결과 또는 지도 핀)를 DB에 저장하거나 갱신한다.
     * 
     * @param command 장소 정보 커맨드
     * @return 저장/갱신된 Place 엔티티
     */
    Place saveUserSelectedPlace(PlaceUpsertCommand command);
}
