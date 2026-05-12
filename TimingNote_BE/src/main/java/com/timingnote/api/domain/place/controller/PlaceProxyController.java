package com.timingnote.api.domain.place.controller;

import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.dto.response.ReverseGeocodeResponse;
import com.timingnote.api.domain.place.service.PlaceProxyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 카카오 Local API 프록시 컨트롤러.
 *
 * 모바일 앱에서 REST API 키 직접 호출 → 디컴파일로 키 탈취 가능한 보안 이슈를 해결하기 위해
 * BE를 거치도록 한다. 키는 BE의 환경변수(application.yml: kakao.api.key)에만 존재하고,
 * 카카오 개발자센터에서 BE 서버 IP를 허용 IP로 등록해 외부 호출 차단.
 *
 * 단계 1: 순수 프록시 (캐시 없음)
 * 단계 2(예정): Redis 캐시로 사용자 간 공유 캐시 + quota 절감
 *
 * 인증: DeviceSecretAuthInterceptor(/api/v1/** 자동 적용) — X-Device-Secret 헤더 필요.
 */
@RestController
@RequestMapping("/api/v1/places")
@RequiredArgsConstructor
@Tag(name = "Place Proxy", description = "카카오 Local API 프록시")
public class PlaceProxyController {

    private final PlaceProxyService placeProxyService;

    @Operation(summary = "장소 키워드 검색",
            description = "카카오 키워드 검색 프록시. 사용자 좌표 제공 시 거리순(반경 20km), 미제공 시 정확도순.")
    @GetMapping("/search")
    public ApiResponseDto<List<PlaceSearchItemResponse>> searchByKeyword(
            @RequestParam("query") String query,
            @RequestParam(value = "lat", required = false) Double userLatitude,
            @RequestParam(value = "lng", required = false) Double userLongitude,
            @RequestParam(value = "size", defaultValue = "15") int size
    ) {
        List<PlaceSearchItemResponse> results = placeProxyService.searchByKeyword(
                query, userLatitude, userLongitude, size);
        return ApiResponseDto.success(results);
    }

    @Operation(summary = "좌표 → 주소 변환 (역지오코딩)",
            description = "카카오 coord2address 프록시. 도로명 우선, 없으면 지번 주소.")
    @GetMapping("/reverse-geocode")
    public ApiResponseDto<ReverseGeocodeResponse> reverseGeocode(
            @RequestParam("lat") double latitude,
            @RequestParam("lng") double longitude
    ) {
        String address = placeProxyService.reverseGeocode(latitude, longitude);
        return ApiResponseDto.success(new ReverseGeocodeResponse(address));
    }
}
