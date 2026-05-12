package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import com.timingnote.api.infra.client.kakao.dto.KakaoReverseGeocodeResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlaceProxyServiceImpl implements PlaceProxyService {

    private final KakaoLocalClient kakaoLocalClient;
    private final KakaoGeoClient kakaoGeoClient;

    @Override
    public List<PlaceSearchItemResponse> searchByKeyword(
            String query,
            Double userLatitude,
            Double userLongitude,
            int size
    ) {
        if (query == null || query.isBlank()) return Collections.emptyList();

        final int clampedSize = Math.max(1, Math.min(size, 15));
        final String x = userLongitude == null ? null : userLongitude.toString();
        final String y = userLatitude == null ? null : userLatitude.toString();
        final boolean sortByDistance = (userLatitude != null && userLongitude != null);

        KakaoLocalSearchResponse response = kakaoLocalClient
                .searchByKeyword(query.trim(), x, y, clampedSize)
                .block();

        int resultCount = (response == null || response.getDocuments() == null)
                ? 0
                : response.getDocuments().size();
        // BE 프록시 경유 확인용 로그. 단계 2(Redis 캐시) 도입 시 hit/miss 분기도 같이 찍는다.
        log.info("[PLACE_PROXY][SEARCH] query='{}' sortByDistance={} size={} → results={}",
                query.trim(), sortByDistance, clampedSize, resultCount);

        if (response == null || response.getDocuments() == null) {
            return Collections.emptyList();
        }
        return response.getDocuments().stream()
                .map(PlaceSearchItemResponse::from)
                .toList();
    }

    @Override
    public String reverseGeocode(double latitude, double longitude) {
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

        log.info("[PLACE_PROXY][REVERSE_GEOCODE] lat={} lng={} → matched={}",
                latitude, longitude, address != null);
        return address;
    }
}
