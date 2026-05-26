package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 장소 도메인의 핵심 비즈니스 로직을 제공하는 서비스 구현체.
 * 
 * 주요 흐름:
 * 1. 통합 검색(searchAndStoreAll): 카카오 API 결과를 조회하고, 이를 우리 DB에 최신화(Upsert)하여 POI 자산화.
 * 2. 개별 저장(saveUserSelectedPlace): 사용자가 선택한 특정 장소나 지도 핀 정보를 DB에 반영.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PlaceServiceImpl implements PlaceService {

    private final KakaoLocalClient kakaoLocalClient;
    private final PlaceRepository placeRepository;
    private final PlaceSearchCache placeSearchCache;
    private final PlaceCacheMetrics metrics;

    /**
     * 키워드와 좌표를 기준으로 장소를 검색하고, 결과를 DB에 누적 또는 갱신한다.
     * 
     * @param placeText 검색 키워드
     * @param latitude  위도
     * @param longitude 경도
     * @return 검색 결과 DTO 리스트와 DB에 반영된 엔티티 리스트
     */
    @Override
    @Transactional
    public SearchResult searchAndStoreAll(String placeText, Double latitude, Double longitude) {
        log.info("[SEARCH_ALL] 장소 검색 시작: keyword='{}'", placeText);

        if (placeText == null || placeText.isBlank() || !isCoordRangeValid(latitude, longitude)) {
            return SearchResult.empty();
        }

        final String x = toLon(longitude);
        final String y = toLat(latitude);

        // 1. Redis 캐시 확인 및 카카오 API 호출 (7일 TTL, 1km grid 단위 공유)
        List<PlaceSearchItemResponse> items = placeSearchCache.getOrLoadSearch(
                placeText, latitude, longitude,
                () -> {
                    try {
                        metrics.kakaoSearchLoad();
                        KakaoLocalSearchResponse res = kakaoLocalClient.searchByKeyword(placeText, x, y).block();
                        
                        if (res == null || res.getDocuments() == null) return Collections.emptyList();
                        
                        return res.getDocuments().stream()
                                .map(PlaceSearchItemResponse::from)
                                .toList();
                    } catch (Exception e) {
                        log.error("[SEARCH_ALL] 카카오 API 호출 실패: {}", e.getMessage());
                        return Collections.emptyList();
                    }
                });

        if (items.isEmpty()) return SearchResult.empty();

        // 2. 검색된 장소들을 DB에 Upsert (최신 정보 동기화)
        List<Place> stored = saveOrUpdateCandidates(items);
        return new SearchResult(items, stored);
    }

    /**
     * 사용자가 선택한 장소 정보를 DB에 저장하거나 갱신한다.
     * 
     * @param cmd 저장할 장소 정보 커맨드
     * @return 저장된 Place 엔티티
     */
    @Override
    @Transactional
    public Place saveUserSelectedPlace(PlaceUpsertCommand cmd) {
        log.info("[Place/Save] 사용자 선택 장소 처리: name='{}'", cmd.placeName());

        // 1. 지도 핀 (사용자 지정 좌표) 처리: 주소 기반 중복 제거
        if (cmd.kakaoPlaceId() == null) {
            return lookupPinByAddress(cmd.roadAddressName(), cmd.addressName())
                    .orElseGet(() -> placeRepository.save(Place.builder()
                            .name(cmd.placeName())
                            .address(cmd.addressName())
                            .roadAddress(cmd.roadAddressName())
                            .location(Place.toPoint(cmd.longitude(), cmd.latitude()))
                            .build()));
        }

        // 2. 카카오 장소 처리: externalPlaceId 기반 Upsert
        return placeRepository.findByExternalPlaceId(cmd.kakaoPlaceId())
                .map(existing -> updatePlaceFromCommand(existing, cmd))
                .orElseGet(() -> placeRepository.save(Place.builder()
                        .externalPlaceId(cmd.kakaoPlaceId())
                        .name(cmd.placeName())
                        .address(cmd.addressName())
                        .roadAddress(cmd.roadAddressName())
                        .categoryGroupCode(cmd.categoryGroupCode())
                        .categoryGroupName(cmd.categoryGroupName())
                        .phone(cmd.phone())
                        .placeUrl(cmd.placeUrl())
                        .location(Place.toPoint(cmd.longitude(), cmd.latitude()))
                        .build()));
    }

    /**
     * 검색된 후보 장소들을 DB에 벌크로 조회하여 존재 여부에 따라 저장 또는 수정을 수행한다.
     */
    private List<Place> saveOrUpdateCandidates(List<PlaceSearchItemResponse> items) {
        List<String> ids = items.stream().map(PlaceSearchItemResponse::getId).toList();

        // SELECT 1회로 기존 매핑 정보 로드
        Map<String, Place> existingMap = placeRepository.findAllByExternalPlaceIdIn(ids).stream()
                .collect(Collectors.toMap(Place::getExternalPlaceId, p -> p));

        return items.stream()
                .map(item -> {
                    Place existing = existingMap.get(item.getId());
                    if (existing != null) {
                        // 기존 장소 정보 최신화 (JPA Dirty Checking 활용)
                        existing.updateBasicInfo(
                                item.getPlaceName(), item.getCategoryName(),
                                item.getAddressName(), item.getRoadAddressName(),
                                item.getPhone(), item.getPlaceUrl()
                        );
                        return existing;
                    } else {
                        // 신규 장소 등록
                        return placeRepository.save(Place.builder()
                                .externalPlaceId(item.getId())
                                .name(item.getPlaceName())
                                .categoryName(item.getCategoryName())
                                .categoryGroupCode(item.getCategoryGroupCode())
                                .categoryGroupName(item.getCategoryGroupName())
                                .address(item.getAddressName())
                                .roadAddress(item.getRoadAddressName())
                                .phone(item.getPhone())
                                .placeUrl(item.getPlaceUrl())
                                .location(Place.toPoint(item.getLongitude(), item.getLatitude()))
                                .build());
                    }
                })
                .toList();
    }

    private Place updatePlaceFromCommand(Place place, PlaceUpsertCommand cmd) {
        place.updateBasicInfo(
                cmd.placeName(), place.getCategoryName(),
                cmd.addressName(), cmd.roadAddressName(),
                cmd.phone(), cmd.placeUrl()
        );
        return place;
    }

    private Optional<Place> lookupPinByAddress(String roadAddress, String address) {
        if (roadAddress != null && !roadAddress.isBlank()) {
            Optional<Place> byRoad = placeRepository.findFirstByExternalPlaceIdIsNullAndRoadAddress(roadAddress);
            if (byRoad.isPresent()) return byRoad;
        }
        if (address != null && !address.isBlank()) {
            return placeRepository.findFirstByExternalPlaceIdIsNullAndAddress(address);
        }
        return Optional.empty();
    }

    private static String toLon(Double longitude) { return longitude != null ? String.valueOf(longitude) : null; }
    private static String toLat(Double latitude) { return latitude != null ? String.valueOf(latitude) : null; }

    private static boolean isCoordRangeValid(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) return true;
        return Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180;
    }
}
