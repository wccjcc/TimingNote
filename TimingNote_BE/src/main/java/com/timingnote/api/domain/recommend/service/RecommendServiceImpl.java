package com.timingnote.api.domain.recommend.service;

import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoRegionCodeResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class RecommendServiceImpl implements RecommendService {

    private final KakaoGeoClient kakaoGeoClient;

    @Override
    public RecommendListResponseDto getRecommendations(Long userId, RecommendListRequestDto requestDto) {
        String currentLocationLabel = resolveCurrentLocationLabel(
                requestDto.getLatitude(),
                requestDto.getLongitude()
        );

        // TODO: 추천 비즈니스 로직 구현 전까지 아이템은 빈 목록 반환
        return RecommendListResponseDto.builder()
                .currentLocationLabel(currentLocationLabel)
                .items(List.of())
                .build();
    }

    //Kakao 좌표->행정구역정보변환 API를 호출해서 현재 위치가 어디인지 반환
    private String resolveCurrentLocationLabel(double latitude, double longitude) {
        KakaoRegionCodeResponse response = kakaoGeoClient
                .coordToRegionCode(String.valueOf(longitude), String.valueOf(latitude))
                .block();

        if (response == null || response.getDocuments() == null || response.getDocuments().isEmpty()) {
            return null;
        }

        KakaoRegionCodeResponse.Document target = response.getDocuments().stream()
                .filter(doc -> "H".equalsIgnoreCase(doc.getRegionType()))
                .findFirst()
                .orElse(response.getDocuments().get(0));

        String depth1 = safe(target.getRegion1DepthName()); // 시/도
        String depth3 = safe(target.getRegion3DepthName()); // 동/읍/면
        String depth4 = safe(target.getRegion4DepthName()); // 리

        if (!depth1.isEmpty() && !depth3.isEmpty()) {
            return depth1 + " " + depth3;
        }
        if (!depth1.isEmpty() && !depth4.isEmpty()) {
            return depth1 + " " + depth4;
        }
        if (!depth1.isEmpty()) {
            return depth1;
        }

        String addressName = safe(target.getAddressName());
        return addressName.isEmpty() ? null : addressName;
    }

    private String safe(String value) {
        return value == null ? "" : value.trim();
    }
}
