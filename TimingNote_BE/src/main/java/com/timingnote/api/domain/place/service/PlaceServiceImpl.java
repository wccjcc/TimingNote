package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.PlaceOpeningPeriod;
import com.timingnote.api.domain.place.repository.PlaceOpeningPeriodRepository;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.infra.client.google.GooglePlacesClient;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchResponse;
import com.timingnote.api.infra.client.google.dto.GoogleOpeningHours;
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

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Collections;
import java.util.Comparator;
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
    private final PlaceOpeningPeriodRepository openingPeriodRepository;
    private final ObjectMapper objectMapper;

    private static final int GENERIC_RADIUS = 1000;
    private static final int GENERIC_SIZE   = 15;

    private static final int    OPENING_HOURS_TTL_DAYS     = 30;
    private static final double GENERIC_GOOGLE_RADIUS_M    = 500.0;
    private static final int    GENERIC_GOOGLE_MAX_RESULTS = 20;
    private static final double COORD_MATCH_THRESHOLD_M    = 150.0;

    private static final String PLACE_DETAILS_FIELD_MASK = "regularOpeningHours,businessStatus";

    // ── SPECIFIC ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public Optional<Place> resolveSpecificPlace(String placeText, Double latitude, Double longitude) {
        log.info("[SPECIFIC] 시작: placeText='{}' lat={} lon={}", placeText, latitude, longitude);

        String x = toLon(longitude);
        String y = toLat(latitude);

        KakaoDocument kakaoDoc = searchKeyword(placeText, x, y, 5);
        if (kakaoDoc == null) {
            log.info("[SPECIFIC] 카카오 결과 없음 → Google TextSearch fallback: '{}'", placeText);
            return resolveViaGoogleTextSearch(placeText, latitude, longitude);
        }

        boolean isNew = placeRepository.findByExternalPlaceId(kakaoDoc.getId()).isEmpty();
        Place place = placeRepository.findByExternalPlaceId(kakaoDoc.getId())
                .orElseGet(() -> saveFromKakao(kakaoDoc));
        log.info("[SPECIFIC] 장소 {}(externalId={}): '{}'",
                isNew ? "신규 저장" : "DB 캐시 hit", kakaoDoc.getId(), place.getName());

        if (place.getGooglePlaceId() == null) {
            log.info("[SPECIFIC] googlePlaceId 없음 → TextSearch로 최초 보강");
            enrichWithGoogleTextSearch(place, kakaoDoc.getPlaceName());
        } else if (isHoursExpired(place)) {
            log.info("[SPECIFIC] 영업시간 TTL 만료 (hoursFetchedAt={}) → Place Details 갱신",
                    place.getHoursFetchedAt());
            refreshWithPlaceDetails(place);
        } else {
            log.info("[SPECIFIC] 영업시간 캐시 유효 (hoursFetchedAt={}) → Google 호출 스킵",
                    place.getHoursFetchedAt());
        }

        log.info("[SPECIFIC] 완료: placeText='{}' → place.id={}", placeText, place.getId());
        return Optional.of(place);
    }

    // ── GENERIC ──────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<Place> resolveGenericCandidates(String placeText, Double latitude, Double longitude) {
        log.info("[GENERIC] 시작: placeText='{}' lat={} lon={}", placeText, latitude, longitude);

        if (latitude == null || longitude == null) {
            log.warn("[GENERIC] 좌표 없음 → 장소 연동 스킵: '{}'", placeText);
            return Collections.emptyList();
        }

        String x = toLon(longitude);
        String y = toLat(latitude);
        Decision decision = KakaoPlaceSearchStrategy.decide(placeText);
        log.info("[GENERIC] 전략 결정: useCategory={} code={}",
                decision.useCategory(), decision.categoryGroupCode());

        KakaoLocalSearchResponse response;
        if (decision.useCategory()) {
            response = searchByCategory(decision.categoryGroupCode(), x, y);
        } else {
            response = searchKeywordNearby(placeText, x, y);
        }

        if (response == null || response.getDocuments() == null || response.getDocuments().isEmpty()) {
            log.warn("[GENERIC] 카카오 결과 없음: '{}'", placeText);
            return Collections.emptyList();
        }

        log.info("[GENERIC] 카카오 결과 {}개", response.getDocuments().size());

        List<Place> places = saveCandidates(response.getDocuments());
        log.info("[GENERIC] 후보 장소 {}개 확보 (신규+기존 합산)", places.size());

        batchEnrichOpeningHours(places, placeText, latitude, longitude);

        log.info("[GENERIC] 완료: placeText='{}' → 후보 {}개", placeText, places.size());
        return places;
    }

    // ── Kakao 검색 헬퍼 ─────────────────────────────────────────────────────

    private KakaoDocument searchKeyword(String query, String x, String y, int size) {
        log.info("[Kakao/Keyword] 검색: query='{}' x={} y={} size={}", query, x, y, size);
        try {
            KakaoLocalSearchResponse res = kakaoLocalClient.searchByKeyword(query, x, y, size).block();
            if (res == null || res.getDocuments() == null || res.getDocuments().isEmpty()) {
                log.warn("[Kakao/Keyword] 결과 없음: '{}'", query);
                return null;
            }

            List<KakaoDocument> docs = res.getDocuments();
            log.info("[Kakao/Keyword] 결과 {}개:", docs.size());
            for (int i = 0; i < docs.size(); i++) {
                KakaoDocument d = docs.get(i);
                log.info("  [{}] '{}' category={} distance={}m id={}",
                        i + 1, d.getPlaceName(), d.getCategoryGroupCode(),
                        d.getDistance(), d.getId());
            }

            KakaoDocument best = pickBestMatch(docs, query);
            log.info("[Kakao/Keyword] 최종 선택: '{}' (categoryCode={})",
                    best.getPlaceName(), best.getCategoryGroupCode());
            return best;
        } catch (Exception e) {
            log.error("[Kakao/Keyword] 검색 실패: '{}' - {}", query, e.getMessage());
            return null;
        }
    }

    private KakaoDocument pickBestMatch(List<KakaoDocument> docs, String query) {
        String expectedCode = KakaoPlaceSearchStrategy.decide(query).categoryGroupCode();
        if (expectedCode != null) {
            List<KakaoDocument> byCategory = docs.stream()
                    .filter(d -> expectedCode.equals(d.getCategoryGroupCode()))
                    .toList();
            if (!byCategory.isEmpty()) {
                log.info("[Kakao/Keyword] 카테고리 필터({}): {}개 → 이름 매칭",
                        expectedCode, byCategory.size());
                return pickByName(byCategory, query);
            }
            log.info("[Kakao/Keyword] 카테고리 필터({}) 해당 없음 → 전체 이름 매칭", expectedCode);
        }
        return pickByName(docs, query);
    }

    private KakaoDocument pickByName(List<KakaoDocument> docs, String query) {
        String nq = normalize(query);
        for (KakaoDocument doc : docs) {
            if (normalize(doc.getPlaceName()).equals(nq)) {
                log.info("[Kakao/Keyword] 이름 완전일치: '{}'", doc.getPlaceName());
                return doc;
            }
        }
        for (KakaoDocument doc : docs) {
            if (nq.contains(normalize(doc.getPlaceName()))) {
                log.info("[Kakao/Keyword] 쿼리⊇장소명 매칭: '{}'", doc.getPlaceName());
                return doc;
            }
        }
        log.info("[Kakao/Keyword] 이름 매칭 없음 → 1순위 fallback: '{}'", docs.get(0).getPlaceName());
        return docs.get(0);
    }

    private KakaoLocalSearchResponse searchKeywordNearby(String query, String x, String y) {
        log.info("[Kakao/KeywordNearby] 검색: query='{}' x={} y={} radius={}m size={}",
                query, x, y, GENERIC_RADIUS, GENERIC_SIZE);
        try {
            KakaoLocalSearchResponse res = kakaoLocalClient
                    .searchByKeywordNearby(query, x, y, GENERIC_RADIUS, GENERIC_SIZE, "distance")
                    .block();
            int count = (res != null && res.getDocuments() != null) ? res.getDocuments().size() : 0;
            log.info("[Kakao/KeywordNearby] 결과 {}개", count);
            return res;
        } catch (Exception e) {
            log.error("[Kakao/KeywordNearby] 실패: '{}' - {}", query, e.getMessage());
            return null;
        }
    }

    private KakaoLocalSearchResponse searchByCategory(String code, String x, String y) {
        log.info("[Kakao/Category] 검색: code={} x={} y={} radius={}m size={}",
                code, x, y, GENERIC_RADIUS, GENERIC_SIZE);
        try {
            KakaoLocalSearchResponse res = kakaoLocalClient
                    .searchByCategory(code, x, y, GENERIC_RADIUS, GENERIC_SIZE, "distance")
                    .block();
            int count = (res != null && res.getDocuments() != null) ? res.getDocuments().size() : 0;
            log.info("[Kakao/Category] 결과 {}개", count);
            return res;
        } catch (Exception e) {
            log.error("[Kakao/Category] 실패: code={} - {}", code, e.getMessage());
            return null;
        }
    }

    private static String normalize(String s) {
        return s.replaceAll("\\s+", "")
                .toLowerCase()
                .replaceAll("(점|지점|branch|店)$", "");
    }

    private static String normalizePhone(String phone) {
        return phone == null ? null : phone.replaceAll("[^0-9]", "");
    }

    // ── Place 저장 ───────────────────────────────────────────────────────────

    private Place saveFromKakao(KakaoDocument doc) {
        log.info("[Place] 카카오 장소 신규 저장: '{}' (externalId={})", doc.getPlaceName(), doc.getId());
        Point location = Place.toPoint(
                Double.parseDouble(doc.getX()),
                Double.parseDouble(doc.getY()));

        return placeRepository.save(Place.builder()
                .externalPlaceId(doc.getId())
                .name(doc.getPlaceName())
                .categoryName(doc.getCategoryName())
                .categoryGroupCode(doc.getCategoryGroupCode())
                .categoryGroupName(doc.getCategoryGroupName())
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

        List<Place> newPlaces = docs.stream()
                .filter(d -> !existing.contains(d.getId()))
                .map(this::saveFromKakao)
                .toList();

        log.info("[Place] 후보 저장: 신규={}개 기존={}개", newPlaces.size(), existing.size());

        return placeRepository.findAllByExternalPlaceIdIn(ids);
    }

    // ── Google 보강 (SPECIFIC 신규) ──────────────────────────────────────────

    private static final double SPECIFIC_ENRICH_MAX_DIST_M = 500.0;

    private void enrichWithGoogleTextSearch(Place place, String kakaoName) {
        log.info("[Google/TextSearch] SPECIFIC 보강 시작: '{}' lat={} lon={}",
                kakaoName, place.getLatitude(), place.getLongitude());
        try {
            GoogleTextSearchRequest request = GoogleTextSearchRequest.builder()
                    .textQuery(kakaoName)
                    .locationBias(GoogleTextSearchRequest.LocationBias.builder()
                            .circle(GoogleTextSearchRequest.Circle.builder()
                                    .center(GoogleTextSearchRequest.LatLng.builder()
                                            .latitude(place.getLatitude())
                                            .longitude(place.getLongitude())
                                            .build())
                                    .radius(SPECIFIC_ENRICH_MAX_DIST_M)
                                    .build())
                            .build())
                    .pageSize(5)
                    .languageCode("ko")
                    .build();

            GoogleNearbySearchResponse response = googlePlacesClient.searchText(request).block();

            if (response == null || response.getPlaces() == null || response.getPlaces().isEmpty()) {
                log.warn("[Google/TextSearch] 결과 없음: '{}'", kakaoName);
                return;
            }

            GooglePlace gp = response.getPlaces().get(0);
            String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "?";

            // 전화번호 일치 시 즉시 확정 (fast path)
            String kakaoPhone = normalizePhone(place.getPhone());
            String googlePhone = normalizePhone(gp.getNationalPhoneNumber());
            boolean phoneConfirmed = kakaoPhone != null && googlePhone != null
                    && (kakaoPhone.equals(googlePhone) || googlePhone.endsWith(kakaoPhone));
            if (phoneConfirmed) {
                log.info("[Google/TextSearch] 전화번호 확정: '{}' kakao={} google={}", gpName, kakaoPhone, googlePhone);
            } else {
                // 전화번호 없거나 불일치 → 거리로 검증
                if (gp.getLocation() == null) {
                    log.warn("[Google/TextSearch] 좌표 없음: '{}'", kakaoName);
                    return;
                }
                double dist = distanceMeters(place.getLatitude(), place.getLongitude(),
                        gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
                if (dist > SPECIFIC_ENRICH_MAX_DIST_M) {
                    log.warn("[Google/TextSearch] 거리 초과 ({}m > {}m) → 스킵: '{}'",
                            (int) dist, (int) SPECIFIC_ENRICH_MAX_DIST_M, kakaoName);
                    return;
                }
                log.info("[Google/TextSearch] 거리 확정: '{}' 거리={}m", gpName, (int) dist);
            }

            boolean hasHours = gp.getRegularOpeningHours() != null;
            log.info("[Google/TextSearch] 매칭 성공: googleName='{}' status={} hasHours={}",
                    gpName, gp.getBusinessStatus(), hasHours);

            place.enrichGoogleData(gp.getId(), serializeHours(gp), gp.getBusinessStatus());
            saveOpeningPeriods(place.getId(), gp.getRegularOpeningHours());
        } catch (Exception e) {
            log.warn("[Google/TextSearch] SPECIFIC 보강 실패 (placeId={}): {}", place.getId(), e.getMessage());
        }
    }

    // ── Google 갱신 (SPECIFIC TTL 만료) ─────────────────────────────────────

    private boolean isHoursExpired(Place place) {
        if (place.getHoursFetchedAt() == null) return true;
        return place.getHoursFetchedAt()
                .isBefore(OffsetDateTime.now(ZoneOffset.UTC).minusDays(OPENING_HOURS_TTL_DAYS));
    }

    private void refreshWithPlaceDetails(Place place) {
        log.info("[Google/Details] 갱신 시작: placeId={} googlePlaceId={}",
                place.getId(), place.getGooglePlaceId());
        try {
            GooglePlace gp = googlePlacesClient
                    .getPlaceDetails(place.getGooglePlaceId(), PLACE_DETAILS_FIELD_MASK)
                    .block();
            if (gp == null) {
                log.warn("[Google/Details] 응답 없음: placeId={}", place.getId());
                return;
            }
            boolean hasHours = gp.getRegularOpeningHours() != null;
            log.info("[Google/Details] 응답: status={} hasHours={}", gp.getBusinessStatus(), hasHours);
            place.enrichGoogleData(place.getGooglePlaceId(), serializeHours(gp), gp.getBusinessStatus());
            saveOpeningPeriods(place.getId(), gp.getRegularOpeningHours());
        } catch (Exception e) {
            log.warn("[Google/Details] 갱신 실패 (placeId={}): {}", place.getId(), e.getMessage());
        }
    }

    // ── Google 일괄 보강 (GENERIC) ───────────────────────────────────────────

    private void batchEnrichOpeningHours(List<Place> places, String placeText,
                                         double latitude, double longitude) {
        if (places.isEmpty()) return;
        log.info("[Google/Batch] 시작: query='{}' 카카오후보={}개 반경={}m",
                placeText, places.size(), (int) GENERIC_GOOGLE_RADIUS_M);
        try {
            GoogleTextSearchRequest request = GoogleTextSearchRequest.builder()
                    .textQuery(placeText)
                    .locationBias(GoogleTextSearchRequest.LocationBias.builder()
                            .circle(GoogleTextSearchRequest.Circle.builder()
                                    .center(GoogleTextSearchRequest.LatLng.builder()
                                            .latitude(latitude)
                                            .longitude(longitude)
                                            .build())
                                    .radius(GENERIC_GOOGLE_RADIUS_M)
                                    .build())
                            .build())
                    .pageSize(GENERIC_GOOGLE_MAX_RESULTS)
                    .languageCode("ko")
                    .build();

            GoogleNearbySearchResponse response = googlePlacesClient.searchText(request).block();

            if (response == null || response.getPlaces() == null) {
                log.warn("[Google/Batch] 응답 없음: query='{}'", placeText);
                return;
            }

            log.info("[Google/Batch] Google 결과 {}개", response.getPlaces().size());

            int matched = 0, noHours = 0, noCoordMatch = 0;

            for (GooglePlace gp : response.getPlaces()) {
                String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "?";

                if (gp.getLocation() == null) {
                    log.debug("[Google/Batch] 좌표 없음: '{}'", gpName);
                    continue;
                }
                if (gp.getRegularOpeningHours() == null) {
                    log.debug("[Google/Batch] 영업시간 없음: '{}'", gpName);
                    noHours++;
                    continue;
                }

                Optional<Place> closest = findClosestPlace(
                        places,
                        gp.getLocation().getLatitude(),
                        gp.getLocation().getLongitude(),
                        COORD_MATCH_THRESHOLD_M);

                if (closest.isPresent()) {
                    Place p = closest.get();
                    double dist = distanceMeters(p.getLatitude(), p.getLongitude(),
                            gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
                    log.info("[Google/Batch] 매칭: kakao='{}' ↔ google='{}' 거리={}m",
                            p.getName(), gpName, (int) dist);
                    p.enrichGoogleData(gp.getId(), serializeHours(gp), gp.getBusinessStatus());
                    saveOpeningPeriods(p.getId(), gp.getRegularOpeningHours());
                    matched++;
                } else {
                    log.debug("[Google/Batch] 좌표 불일치 ({}m 이내 없음): '{}'",
                            (int) COORD_MATCH_THRESHOLD_M, gpName);
                    noCoordMatch++;
                }
            }
            log.info("[Google/Batch] 완료: 매칭={}개 영업시간없음={}개 좌표불일치={}개",
                    matched, noHours, noCoordMatch);
        } catch (Exception e) {
            log.warn("[Google/Batch] 실패 ({}): {}", placeText, e.getMessage());
        }
    }

    // ── Google TextSearch fallback (SPECIFIC 카카오 실패 시) ─────────────────

    private Optional<Place> resolveViaGoogleTextSearch(String placeText, Double latitude, Double longitude) {
        log.info("[Google/TextSearch] fallback 시작: '{}' lat={} lon={}", placeText, latitude, longitude);
        try {
            GoogleTextSearchRequest.GoogleTextSearchRequestBuilder builder = GoogleTextSearchRequest.builder()
                    .textQuery(placeText)
                    .languageCode("ko");

            if (latitude != null && longitude != null) {
                builder.locationBias(GoogleTextSearchRequest.LocationBias.builder()
                        .circle(GoogleTextSearchRequest.Circle.builder()
                                .center(GoogleTextSearchRequest.LatLng.builder()
                                        .latitude(latitude)
                                        .longitude(longitude)
                                        .build())
                                .radius(SPECIFIC_ENRICH_MAX_DIST_M)
                                .build())
                        .build());
            }

            GoogleNearbySearchResponse response = googlePlacesClient
                    .searchText(builder.build())
                    .block();

            if (response == null || response.getPlaces() == null || response.getPlaces().isEmpty()) {
                log.warn("[Google/TextSearch] 결과 없음: '{}'", placeText);
                return Optional.empty();
            }

            log.info("[Google/TextSearch] 결과 {}개 → 1순위 사용", response.getPlaces().size());
            GooglePlace gp = response.getPlaces().get(0);
            if (gp.getLocation() == null) {
                log.warn("[Google/TextSearch] 1순위 좌표 없음: '{}'", placeText);
                return Optional.empty();
            }

            String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : placeText;
            boolean isNew = placeRepository.findByExternalPlaceId(gp.getId()).isEmpty();
            log.info("[Google/TextSearch] 장소 {}: '{}' status={} hasHours={}",
                    isNew ? "신규 저장" : "DB 캐시 hit",
                    gpName, gp.getBusinessStatus(), gp.getRegularOpeningHours() != null);

            Place place = placeRepository.findByExternalPlaceId(gp.getId()).orElseGet(() -> {
                String hoursJson = serializeHours(gp);
                Point location = Place.toPoint(
                        gp.getLocation().getLongitude(),
                        gp.getLocation().getLatitude());
                return placeRepository.save(Place.builder()
                        .externalPlaceId(gp.getId())
                        .googlePlaceId(gp.getId())
                        .name(gpName)
                        .location(location)
                        .regularHoursRaw(hoursJson)
                        .businessStatus(gp.getBusinessStatus())
                        .hoursFetchedAt(hoursJson != null ? OffsetDateTime.now(ZoneOffset.UTC) : null)
                        .build());
            });

            saveOpeningPeriods(place.getId(), gp.getRegularOpeningHours());
            log.info("[Google/TextSearch] 완료: place.id={}", place.getId());
            return Optional.of(place);
        } catch (Exception e) {
            log.error("[Google/TextSearch] 실패: '{}' - {}", placeText, e.getMessage());
            return Optional.empty();
        }
    }

    // ── 영업시간 저장 ─────────────────────────────────────────────────────────

    private void saveOpeningPeriods(Long placeId, GoogleOpeningHours hours) {
        if (hours == null) {
            log.info("[OpeningHours] regularOpeningHours=null → place.id={} 저장 스킵", placeId);
            return;
        }
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        List<PlaceOpeningPeriod> periods = OpeningHoursParser.parse(placeId, hours, now);
        if (periods.isEmpty()) {
            log.info("[OpeningHours] 파싱 결과 0개 → place.id={} 저장 스킵", placeId);
            return;
        }
        openingPeriodRepository.deleteAllByPlaceId(placeId);
        openingPeriodRepository.saveAll(periods);
        log.info("[OpeningHours] place.id={} → {}개 period 저장 완료", placeId, periods.size());
    }

    // ── 공통 유틸 ────────────────────────────────────────────────────────────

    private Optional<Place> findClosestPlace(List<Place> candidates,
                                              double lat, double lon,
                                              double maxDistanceM) {
        return candidates.stream()
                .filter(p -> distanceMeters(p.getLatitude(), p.getLongitude(), lat, lon) <= maxDistanceM)
                .min(Comparator.comparingDouble(
                        p -> distanceMeters(p.getLatitude(), p.getLongitude(), lat, lon)));
    }

    private static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6_371_000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private String serializeHours(GooglePlace gp) {
        if (gp.getRegularOpeningHours() == null) return null;
        try {
            return objectMapper.writeValueAsString(gp.getRegularOpeningHours());
        } catch (JsonProcessingException e) {
            log.warn("[OpeningHours] 직렬화 실패: {}", e.getMessage());
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
