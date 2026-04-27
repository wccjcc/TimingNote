package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.infra.client.google.GooglePlacesClient;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchRequest;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchRequest.Circle;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchRequest.LatLng;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchRequest.LocationRestriction;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchResponse;
import com.timingnote.api.infra.client.google.dto.GooglePlace;
import com.timingnote.api.infra.client.google.dto.GoogleTextSearchRequest;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.KakaoPlaceSearchStrategy;
import com.timingnote.api.infra.client.kakao.KakaoPlaceSearchStrategy.Decision;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlaceServiceImpl implements PlaceService {

    private final KakaoLocalClient kakaoLocalClient;
    private final GooglePlacesClient googlePlacesClient;
    private final PlaceRepository placeRepository;
    private final ObjectMapper objectMapper;

    private static final int GENERIC_RADIUS = 1000;
    private static final int GENERIC_SIZE   = 15;

    // ── SPECIFIC ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public Optional<Place> resolveSpecificPlace(String placeText, Double latitude, Double longitude) {
        String x = toLon(longitude);
        String y = toLat(latitude);

        KakaoDocument kakaoDoc = searchKeyword(placeText, x, y, 1);
        if (kakaoDoc == null) {
            return resolveViaGoogleTextSearch(placeText);
        }

        Place place = placeRepository.findByExternalPlaceId(kakaoDoc.getId())
                .orElseGet(() -> saveFromKakao(kakaoDoc));

        if (place.getGooglePlaceId() == null) {
            enrichWithGoogleNearby(place, kakaoDoc);
        }

        log.info("[Place] SPECIFIC 완료: {} → place.id={}", placeText, place.getId());
        return Optional.of(place);
    }

    // ── GENERIC ──────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<Place> resolveGenericCandidates(String placeText, Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            log.warn("[Place] GENERIC 좌표 없음 — 스킵: {}", placeText);
            return Collections.emptyList();
        }

        String x = toLon(longitude);
        String y = toLat(latitude);
        Decision decision = KakaoPlaceSearchStrategy.decide(placeText);
        KakaoLocalSearchResponse response;

        if (decision.useCategory()) {
            log.info("[Kakao] GENERIC 카테고리 검색: {} → {}", placeText, decision.categoryGroupCode());
            response = searchByCategory(decision.categoryGroupCode(), x, y);
        } else {
            log.info("[Kakao] GENERIC 키워드 검색: {}", placeText);
            response = searchKeywordNearby(placeText, x, y);
        }

        if (response == null || response.getDocuments() == null || response.getDocuments().isEmpty()) {
            log.warn("[Place] GENERIC 후보 없음: {}", placeText);
            return Collections.emptyList();
        }

        return saveCandidates(response.getDocuments());
    }

    // ── Kakao 검색 헬퍼 ─────────────────────────────────────────────────────

    private KakaoDocument searchKeyword(String query, String x, String y, int size) {
        try {
            KakaoLocalSearchResponse res = kakaoLocalClient.searchByKeyword(query, x, y, size).block();
            if (res == null || res.getDocuments() == null || res.getDocuments().isEmpty()) {
                log.warn("[Kakao] keyword 결과 없음: {}", query);
                return null;
            }
            return res.getDocuments().get(0);
        } catch (Exception e) {
            log.error("[Kakao] keyword 검색 실패: {} - {}", query, e.getMessage());
            return null;
        }
    }

    private KakaoLocalSearchResponse searchKeywordNearby(String query, String x, String y) {
        try {
            return kakaoLocalClient
                    .searchByKeywordNearby(query, x, y, GENERIC_RADIUS, GENERIC_SIZE, "distance")
                    .block();
        } catch (Exception e) {
            log.error("[Kakao] keywordNearby 실패: {} - {}", query, e.getMessage());
            return null;
        }
    }

    private KakaoLocalSearchResponse searchByCategory(String code, String x, String y) {
        try {
            return kakaoLocalClient
                    .searchByCategory(code, x, y, GENERIC_RADIUS, GENERIC_SIZE, "distance")
                    .block();
        } catch (Exception e) {
            log.error("[Kakao] category 검색 실패: {} - {}", code, e.getMessage());
            return null;
        }
    }

    // ── Place 저장 ───────────────────────────────────────────────────────────

    private Place saveFromKakao(KakaoDocument doc) {
        Point location = Place.toPoint(
                Double.parseDouble(doc.getX()),
                Double.parseDouble(doc.getY()));

        return placeRepository.save(Place.builder()
                .externalPlaceId(doc.getId())
                .name(doc.getPlaceName())
                .categoryName(doc.getCategoryName())
                .address(doc.getAddressName())
                .roadAddress(doc.getRoadAddressName())
                .phone(doc.getPhone())
                .placeUrl(doc.getPlaceUrl())
                .location(location)
                .build());
    }

    private List<Place> saveCandidates(List<KakaoDocument> docs) {
        List<String> ids = docs.stream().map(KakaoDocument::getId).toList();

        Set<String> existing = placeRepository.findAllByExternalPlaceIdIn(ids)
                .stream().map(Place::getExternalPlaceId).collect(Collectors.toSet());

        List<Place> toSave = docs.stream()
                .filter(d -> !existing.contains(d.getId()))
                .map(this::saveFromKakao)
                .toList();

        if (!toSave.isEmpty()) {
            placeRepository.saveAll(toSave);
        }

        return placeRepository.findAllByExternalPlaceIdIn(ids);
    }

    // ── Google 보강 ──────────────────────────────────────────────────────────

    private void enrichWithGoogleNearby(Place place, KakaoDocument kakaoDoc) {
        try {
            GoogleNearbySearchRequest request = GoogleNearbySearchRequest.builder()
                    .locationRestriction(LocationRestriction.builder()
                            .circle(Circle.builder()
                                    .center(LatLng.builder()
                                            .latitude(place.getLatitude())
                                            .longitude(place.getLongitude())
                                            .build())
                                    .radius(50.0)
                                    .build())
                            .build())
                    .maxResultCount(5)
                    .build();

            GoogleNearbySearchResponse response = googlePlacesClient.searchNearby(request).block();
            if (response == null || response.getPlaces() == null) return;

            findBestNameMatch(response.getPlaces(), kakaoDoc.getPlaceName())
                    .ifPresent(gp -> {
                        place.enrichGoogleData(gp.getId(), serializeHours(gp),
                                gp.getBusinessStatus(), gp.getUtcOffsetMinutes());
                        log.info("[Google] 영업시간 보강: {} (status={}, utcOffset={})",
                                kakaoDoc.getPlaceName(), gp.getBusinessStatus(), gp.getUtcOffsetMinutes());
                    });
        } catch (Exception e) {
            log.warn("[Google] Nearby 보강 실패 (placeId={}): {}", place.getId(), e.getMessage());
        }
    }

    private Optional<Place> resolveViaGoogleTextSearch(String placeText) {
        try {
            GoogleNearbySearchResponse response = googlePlacesClient
                    .searchText(GoogleTextSearchRequest.builder().textQuery(placeText).build())
                    .block();

            if (response == null || response.getPlaces() == null || response.getPlaces().isEmpty())
                return Optional.empty();

            GooglePlace gp = response.getPlaces().get(0);
            if (gp.getLocation() == null) return Optional.empty();

            Place place = placeRepository.findByExternalPlaceId(gp.getId()).orElseGet(() -> {
                String hoursJson = serializeHours(gp);
                Point location = Place.toPoint(
                        gp.getLocation().getLongitude(),
                        gp.getLocation().getLatitude());
                return placeRepository.save(Place.builder()
                        .externalPlaceId(gp.getId())
                        .googlePlaceId(gp.getId())
                        .name(gp.getDisplayName() != null ? gp.getDisplayName().getText() : placeText)
                        .location(location)
                        .regularHoursRaw(hoursJson)
                        .businessStatus(gp.getBusinessStatus())
                        .utcOffsetMinutes(gp.getUtcOffsetMinutes())
                        .hoursFetchedAt(hoursJson != null ? java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC) : null)
                        .build());
            });

            log.info("[Google TextSearch] fallback 완료: {}", placeText);
            return Optional.of(place);
        } catch (Exception e) {
            log.error("[Google TextSearch] fallback 실패: {} - {}", placeText, e.getMessage());
            return Optional.empty();
        }
    }

    // ── 공통 유틸 ────────────────────────────────────────────────────────────

    private Optional<GooglePlace> findBestNameMatch(List<GooglePlace> candidates, String kakaoName) {
        return candidates.stream()
                .filter(p -> p.getDisplayName() != null && p.getDisplayName().getText() != null)
                .filter(p -> {
                    String gName = p.getDisplayName().getText();
                    return gName.contains(kakaoName) || kakaoName.contains(gName);
                })
                .findFirst();
    }

    private String serializeHours(GooglePlace gp) {
        if (gp.getRegularOpeningHours() == null) return null;
        try {
            return objectMapper.writeValueAsString(gp.getRegularOpeningHours());
        } catch (JsonProcessingException e) {
            log.warn("[Google] 영업시간 직렬화 실패: {}", e.getMessage());
            return null;
        }
    }

    private static String toLon(Double longitude) {
        return longitude != null ? String.valueOf(longitude) : null;
    }

    private static String toLat(Double latitude) {
        return latitude != null ? String.valueOf(latitude) : null;
    }
}
