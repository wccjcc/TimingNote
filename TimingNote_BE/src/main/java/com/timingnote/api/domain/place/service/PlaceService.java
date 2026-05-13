package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;

import java.util.List;
import java.util.Optional;

public interface PlaceService {

    /**
     * 통합 검색 + Place DB 누적 — 등록 시점에 1회 호출.
     *
     * <p>2026-05-12 설계 결정: placeType을 검색 전에 정하지 않고, 카카오 결과를 그대로 받아
     * 호출자({@code PlaceTypeResolver})가 카테고리 분포·결과 수로 판정한다.
     *
     * <p>호출 시 radius/sort/size 미지정 — 좌표가 거리 가중치로 작동해 사실상 가까운 매장 우선.
     *
     * @return raw 카카오 문서 + DB에 저장된 Place 리스트 (둘 다 호출자가 사용)
     */
    SearchResult searchAndStoreAll(String placeText, Double latitude, Double longitude);

    /** 카카오 raw 결과 + DB 저장된 Place 리스트. */
    record SearchResult(List<KakaoDocument> rawDocuments, List<Place> storedPlaces) {
        public static SearchResult empty() {
            return new SearchResult(List.of(), List.of());
        }
        public boolean isEmpty() { return rawDocuments.isEmpty(); }
    }

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
