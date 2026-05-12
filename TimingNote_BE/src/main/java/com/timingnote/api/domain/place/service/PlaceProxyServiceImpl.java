package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import com.timingnote.api.infra.client.kakao.dto.KakaoReverseGeocodeResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;

/**
 * 카카오 Local API 프록시 서비스 구현.
 *
 * <p>호출 흐름: {@link PlaceSearchCache}를 먼저 거치고, 캐시 miss일 때만 카카오 호출.
 * 캐시 정책(좌표 grid, TTL, hit/miss 로그)은 cache 컴포넌트에 격리.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PlaceProxyServiceImpl implements PlaceProxyService {

    private final KakaoLocalClient kakaoLocalClient;
    private final KakaoGeoClient kakaoGeoClient;
    private final PlaceSearchCache cache;

    @Override
    public List<PlaceSearchItemResponse> searchByKeyword(
            String query,
            Double userLatitude,
            Double userLongitude,
            int size
    ) {
        if (query == null || query.isBlank()) return Collections.emptyList();

        final int clampedSize = Math.max(1, Math.min(size, 15));
        final boolean sortByDistance = (userLatitude != null && userLongitude != null);

        return cache.getOrLoadSearch(query, userLatitude, userLongitude,
                clampedSize, sortByDistance,
                () -> callKakaoSearch(query.trim(), userLatitude, userLongitude, clampedSize));
    }

    @Override
    public String reverseGeocode(double latitude, double longitude) {
        return cache.getOrLoadReverseGeocode(latitude, longitude,
                () -> callKakaoReverseGeocode(latitude, longitude));
    }

    // ─────────────────────────────────────────────────────────────────
    // 카카오 호출 (cache miss 시에만 실행)
    // ─────────────────────────────────────────────────────────────────

    private List<PlaceSearchItemResponse> callKakaoSearch(
            String query, Double lat, Double lng, int size
    ) {
        final String x = lng == null ? null : lng.toString();
        final String y = lat == null ? null : lat.toString();

        KakaoLocalSearchResponse response = kakaoLocalClient
                .searchByKeyword(query, x, y, size)
                .block();

        int resultCount = (response == null || response.getDocuments() == null)
                ? 0
                : response.getDocuments().size();
        log.info("[PLACE_PROXY][SEARCH][KAKAO] query='{}' size={} → results={}",
                query, size, resultCount);

        if (response == null || response.getDocuments() == null) {
            return Collections.emptyList();
        }
        return response.getDocuments().stream()
                .map(PlaceSearchItemResponse::from)
                .toList();
    }

    private String callKakaoReverseGeocode(double latitude, double longitude) {
        KakaoReverseGeocodeResponse response = kakaoGeoClient
                .reverseGeocode(String.valueOf(longitude), String.valueOf(latitude))
                .block();

        String address = null;
        if (response != null && response.getDocuments() != null
                && !response.getDocuments().isEmpty()) {
            KakaoReverseGeocodeResponse.Document first = response.getDocuments().get(0);
            // 도로명 우선, 없으면 지번
            if (first.getRoadAddress() != null && first.getRoadAddress().getAddressName() != null) {
                address = first.getRoadAddress().getAddressName();
            } else if (first.getAddress() != null && first.getAddress().getAddressName() != null) {
                address = first.getAddress().getAddressName();
            }
        }

        log.info("[PLACE_PROXY][REVERSE_GEOCODE][KAKAO] lat={} lng={} → matched={}",
                latitude, longitude, address != null);
        return address;
    }
}
