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
     * Google 영업시간 보강은 트랜잭션 커밋 후 비동기로 수행된다.
     */
    Place saveUserSelectedPlace(PlaceUpsertCommand command);

    // ── 비동기 영업시간 보강 진입점 ────────────────────────────────────────
    // 호출자: PlaceEnrichmentEventListener (AFTER_COMMIT + @Async)
    // 리스너에서 placeId로 다시 로드 → fresh 트랜잭션에서 Google 호출 + 저장.

    /** 신규 보강(googlePlaceId 없음) — Place name 기반 TextSearch 매칭 후 저장. */
    void enrichOpeningHoursByPlaceId(Long placeId);

    /** TTL 만료 갱신 — 이미 매핑된 googlePlaceId로 Place Details 호출. */
    void refreshOpeningHoursByPlaceId(Long placeId);

    /** GENERIC 후보 일괄 보강 — 한 번의 Google TextSearch로 N개 후보 매칭. */
    void enrichCandidatesByPlaceIds(List<Long> placeIds, String placeText,
                                    double latitude, double longitude);
}
