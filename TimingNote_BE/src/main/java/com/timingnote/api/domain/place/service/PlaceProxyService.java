package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;

import java.util.List;

/**
 * FE에서 사용하는 카카오 Local API 프록시 서비스.
 *
 * 모바일 앱에서 카카오 REST API 키를 직접 들고 호출하면 디컴파일로 키 탈취가 가능하다.
 * BE를 거치면:
 * - 키가 서버에만 존재 (+ 허용 IP 설정 가능)
 * - 추후 응답 캐시(Redis) 추가 시 사용자 간 공유 캐시로 quota 절감
 *
 * 거리순(sortByDistance=true) 호출은 사용자 좌표 기준 반경 20km 검색이 된다.
 * 좌표 미지정 시 정확도순 전국 검색.
 */
public interface PlaceProxyService {

    /**
     * 키워드 검색.
     * @param query 검색어 (필수, blank 시 빈 결과)
     * @param userLatitude  사용자 위도. null이면 정확도순.
     * @param userLongitude 사용자 경도. null이면 정확도순.
     * @param size 1~15
     */
    List<PlaceSearchItemResponse> searchByKeyword(
            String query,
            Double userLatitude,
            Double userLongitude,
            int size
    );

    /**
     * 좌표 → 주소 변환. 도로명 우선, 없으면 지번. 주소 매칭 실패 시 null.
     */
    String reverseGeocode(double latitude, double longitude);
}
