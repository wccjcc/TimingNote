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

        KakaoLocalSearchResponse response = kakaoLocalClient
                .searchByKeyword(query.trim(), x, y, clampedSize)
                .block();

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

        if (response == null || response.getDocuments() == null
                || response.getDocuments().isEmpty()) {
            return null;
        }
        KakaoReverseGeocodeResponse.Document first = response.getDocuments().get(0);
        // 도로명 우선, 없으면 지번
        if (first.getRoadAddress() != null && first.getRoadAddress().getAddressName() != null) {
            return first.getRoadAddress().getAddressName();
        }
        if (first.getAddress() != null && first.getAddress().getAddressName() != null) {
            return first.getAddress().getAddressName();
        }
        return null;
    }
}
