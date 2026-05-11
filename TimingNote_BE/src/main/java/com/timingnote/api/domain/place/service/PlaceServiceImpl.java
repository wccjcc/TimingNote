package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.common.util.GeoUtils;
import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.PlaceOpeningPeriod;
import com.timingnote.api.domain.place.event.CandidateBatchEnrichmentEvent;
import com.timingnote.api.domain.place.event.PlaceEnrichmentRequestedEvent;
import com.timingnote.api.domain.place.event.PlaceEnrichmentRequestedEvent.EnrichmentType;
import com.timingnote.api.domain.place.repository.PlaceOpeningPeriodRepository;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.place.service.matching.KakaoGoogleCategoryMapping;
import com.timingnote.api.domain.place.service.matching.PlaceNameSimilarity;
import com.timingnote.api.infra.client.google.GooglePlacesClient;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchResponse;
import com.timingnote.api.infra.client.google.dto.GoogleOpeningHours;
import com.timingnote.api.infra.client.google.dto.GooglePlace;
import com.timingnote.api.infra.client.google.dto.GoogleTextSearchRequest;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoDocument;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Point;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;

import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlaceServiceImpl implements PlaceService {

    private final KakaoLocalClient kakaoLocalClient;
    private final GooglePlacesClient googlePlacesClient;
    private final PlaceRepository placeRepository;
    private final PlaceOpeningPeriodRepository openingPeriodRepository;
    private final ObjectMapper objectMapper;
    private final ApplicationEventPublisher eventPublisher;

    // 3km — 도심 활동 사용자의 가까운 매장을 거리순으로 N개 확보하는 범위.
    // 더 키워도 의미가 크지 않고(멀리 있는 매장은 알림 가치 약함), "유의미한 이동" 트리거 시
    // 새 좌표 기준으로 재검색되므로 시외로 나가면 자연 갱신된다.
    private static final int GENERIC_RADIUS = 3000;
    private static final int GENERIC_SIZE   = 10;

    private static final int    OPENING_HOURS_TTL_DAYS     = 30;
    private static final double GENERIC_GOOGLE_RADIUS_M    = 500.0;
    private static final int    GENERIC_GOOGLE_MAX_RESULTS = 20;
    private static final double COORD_MATCH_THRESHOLD_M    = 100.0;

    private static final String PLACE_DETAILS_FIELD_MASK =
            "regularOpeningHours,businessStatus,primaryType,nationalPhoneNumber";

    // SPECIFIC 매칭 — 점수 가중치 (합 1.0)
    private static final double WEIGHT_DISTANCE = 0.4;
    private static final double WEIGHT_NAME     = 0.6;

    // ── SPECIFIC ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public Optional<Place> resolveSpecificPlace(String placeText, Double latitude, Double longitude) {
        log.info("[SPECIFIC] 시작: placeText='{}' lat={} lon={}", placeText, latitude, longitude);

        // 외부 API(Kakao/Google)에 invalid 입력이 흘러가지 않도록 진입부에서 차단.
        // Google Places New API는 textQuery 빈 문자열이면 400 INVALID_ARGUMENT를 던진다.
        if (placeText == null || placeText.isBlank()) {
            log.warn("[SPECIFIC] placeText 비어있음 → 스킵");
            return Optional.empty();
        }
        if (!isCoordRangeValid(latitude, longitude)) {
            log.warn("[SPECIFIC] 좌표 범위 초과 → 스킵: lat={} lon={}", latitude, longitude);
            return Optional.empty();
        }

        String x = toLon(longitude);
        String y = toLat(latitude);

        KakaoDocument kakaoDoc = searchKeyword(placeText, x, y, 5);
        if (kakaoDoc == null) {
            log.info("[SPECIFIC] 카카오 결과 없음 — Google 보강 비활성화 상태이므로 매칭 실패 처리: '{}'", placeText);
            // [enrichment 비활성화] Google TextSearch fallback 일시 중단. 매핑 정확도 vs 복잡도
            // trade-off 재검토 후 영업시간 데이터가 정말 필요하면 아래 주석 해제 + Google 클라이언트 재활성화.
            // return resolveViaGoogleTextSearch(placeText, latitude, longitude);
            return Optional.empty();
        }

        Optional<Place> existing = placeRepository.findByExternalPlaceId(kakaoDoc.getId());
        boolean isNew = existing.isEmpty();
        Place place = existing.orElseGet(() -> saveFromKakao(kakaoDoc));
        log.info("[SPECIFIC] 장소 {}(externalId={}): '{}'",
                isNew ? "신규 저장" : "DB 캐시 hit", kakaoDoc.getId(), place.getName());

        // [enrichment 비활성화] Google 영업시간 보강 이벤트 발행 전부 일시 중단.
        /*
        if (place.getGooglePlaceId() == null) {
            log.info("[SPECIFIC] googlePlaceId 없음 → 영업시간 보강 이벤트 발행 (async, AFTER_COMMIT)");
            eventPublisher.publishEvent(
                    new PlaceEnrichmentRequestedEvent(place.getId(), EnrichmentType.INITIAL));
        } else if (isHoursExpired(place)) {
            log.info("[SPECIFIC] 영업시간 TTL 만료 (hoursFetchedAt={}) → 갱신 이벤트 발행 (async)",
                    place.getHoursFetchedAt());
            eventPublisher.publishEvent(
                    new PlaceEnrichmentRequestedEvent(place.getId(), EnrichmentType.REFRESH));
        } else {
            log.info("[SPECIFIC] 영업시간 캐시 유효 (hoursFetchedAt={}) → 보강 스킵",
                    place.getHoursFetchedAt());
        }
        */

        log.info("[SPECIFIC] 완료: placeText='{}' → place.id={}", placeText, place.getId());
        return Optional.of(place);
    }

    // ── GENERIC ──────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<Place> resolveGenericCandidates(String placeText, Double latitude, Double longitude) {
        log.info("[GENERIC] 시작: placeText='{}' lat={} lon={}", placeText, latitude, longitude);

        if (placeText == null || placeText.isBlank()) {
            log.warn("[GENERIC] placeText 비어있음 → 스킵");
            return Collections.emptyList();
        }
        if (latitude == null || longitude == null) {
            log.warn("[GENERIC] 좌표 없음 → 장소 연동 스킵: '{}'", placeText);
            return Collections.emptyList();
        }
        if (!isCoordRangeValid(latitude, longitude)) {
            log.warn("[GENERIC] 좌표 범위 초과 → 스킵: lat={} lon={}", latitude, longitude);
            return Collections.emptyList();
        }

        String x = toLon(longitude);
        String y = toLat(latitude);

        // placeText 그대로 키워드 검색만 사용 (radius={@link #GENERIC_RADIUS}, sort=distance).
        // 과거 KakaoPlaceSearchStrategy로 브랜드명까지 카테고리 검색으로 라우팅했으나,
        // "메가커피"가 주변 카페 전부를 후보로 잡는 부작용이 있어 키워드 검색으로 일원화.
        KakaoLocalSearchResponse response = searchKeywordNearby(placeText, x, y);

        if (response == null || response.getDocuments() == null || response.getDocuments().isEmpty()) {
            log.warn("[GENERIC] 카카오 결과 없음: '{}'", placeText);
            return Collections.emptyList();
        }

        log.info("[GENERIC] 카카오 결과 {}개", response.getDocuments().size());

        List<Place> places = saveCandidates(response.getDocuments());
        log.info("[GENERIC] 후보 장소 {}개 확보 (신규+기존 합산)", places.size());

        // [enrichment 비활성화] Google 영업시간 보강 이벤트 발행 일시 중단.
        /*
        eventPublisher.publishEvent(new CandidateBatchEnrichmentEvent(
                places.stream().map(Place::getId).toList(),
                placeText, latitude, longitude));
        */

        log.info("[GENERIC] 완료: placeText='{}' → 후보 {}개", placeText, places.size());
        return places;
    }

    // ── 사용자 선택 장소 저장 ─────────────────────────────────────────────────

    @Override
    @Transactional
    public Place saveUserSelectedPlace(PlaceUpsertCommand cmd) {
        log.info("[Place/UserSelected] 시작: kakaoPlaceId='{}' name='{}'", cmd.kakaoPlaceId(), cmd.placeName());

        // 지도 마커(핀) - kakaoPlaceId 없음 → 항상 신규 저장 (dedup 없음)
        // 지도 마커는 카테고리/전화 메타가 없어 Google 매칭 정확도가 떨어지므로 보강 스킵
        if (cmd.kakaoPlaceId() == null) {
            Place saved = placeRepository.save(Place.builder()
                    .name(cmd.placeName())
                    .address(cmd.addressName())
                    .roadAddress(cmd.roadAddressName())
                    .location(Place.toPoint(cmd.longitude(), cmd.latitude()))
                    .build());
            log.info("[Place/UserSelected] 지도 마커 신규 저장 (영업시간 보강 skip): placeId={}", saved.getId());
            return saved;
        }

        // Kakao 검색 결과 - externalPlaceId로 dedup, 신규/TTL 만료 시 Google 보강
        Optional<Place> existing = placeRepository.findByExternalPlaceId(cmd.kakaoPlaceId());
        boolean isNew = existing.isEmpty();
        Place place = existing.orElseGet(() -> {
            Place saved = placeRepository.save(Place.builder()
                    .externalPlaceId(cmd.kakaoPlaceId())
                    .name(cmd.placeName())
                    .address(cmd.addressName())
                    .roadAddress(cmd.roadAddressName())
                    .categoryGroupCode(cmd.categoryGroupCode())
                    .categoryGroupName(cmd.categoryGroupName())
                    .phone(cmd.phone())
                    .placeUrl(cmd.placeUrl())
                    .location(Place.toPoint(cmd.longitude(), cmd.latitude()))
                    .build());
            log.info("[Place/UserSelected] Kakao 장소 신규 저장: placeId={}", saved.getId());
            return saved;
        });

        // [enrichment 비활성화] Google 영업시간 보강 이벤트 발행 일시 중단.
        /*
        if (place.getGooglePlaceId() == null) {
            log.info("[Place/UserSelected] googlePlaceId 없음 → 영업시간 보강 이벤트 발행 (async)");
            eventPublisher.publishEvent(
                    new PlaceEnrichmentRequestedEvent(place.getId(), EnrichmentType.INITIAL));
        } else if (isHoursExpired(place)) {
            log.info("[Place/UserSelected] 영업시간 TTL 만료 → 갱신 이벤트 발행 (async)");
            eventPublisher.publishEvent(
                    new PlaceEnrichmentRequestedEvent(place.getId(), EnrichmentType.REFRESH));
        } else {
            log.info("[Place/UserSelected] 영업시간 캐시 유효 → 보강 스킵");
        }
        */
        return place;
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
        // 카카오 검색 결과(query 기반) 중 이름 매칭으로 best 1개를 고른다.
        // 과거에는 KakaoPlaceSearchStrategy.decide(query).categoryGroupCode() 로 1차 카테고리
        // 필터를 적용했으나, 키워드 매핑 자체가 휴리스틱이라 제거하고 이름 매칭만 사용한다.
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

    private static String normalize(String s) {
        return s.replaceAll("\\s+", "")
                .toLowerCase()
                .replaceAll("(점|지점|branch|店)$", "");
    }

    /**
     * Phone 정규화 — 숫자만 추출하고 길이/대표번호 검증.
     *
     * 반환 null 케이스:
     *  - 입력 null 또는 빈 문자열
     *  - 정규화 후 8자리 미만 (한국 전화 최소 8자리: 1577-XXXX 대표번호 포함)
     *  - **대표번호 (1577/1588/1644/1666/1899-XXXX)** — 같은 브랜드 다른 지점이
     *    같은 번호를 공유하므로 매칭 시그널로 사용 불가
     *
     * 이전 버전은 빈 문자열 → "" 반환 → endsWith("") 항상 true 라는 매칭 버그가 있었음.
     */
    private static String normalizePhone(String phone) {
        if (phone == null) return null;
        String digits = phone.replaceAll("[^0-9]", "");
        if (digits.length() < 8) return null;
        if (isRepresentativeNumber(digits)) return null;
        return digits;
    }

    /**
     * 1577/1588/1644/1666/1899로 시작하는 8자리 = 한국 대표번호.
     * 같은 기업의 모든 지점이 공유하므로 phone 단일 매칭에 부적합.
     */
    private static boolean isRepresentativeNumber(String digits) {
        if (digits.length() != 8) return false;
        return digits.startsWith("1577")
                || digits.startsWith("1588")
                || digits.startsWith("1644")
                || digits.startsWith("1666")
                || digits.startsWith("1899")
                || digits.startsWith("1670")
                || digits.startsWith("1600")
                || digits.startsWith("1522")
                || digits.startsWith("1599");
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

        // SELECT 1회: 기존 Place 엔티티를 바로 보존 (ID 추출 후 재조회 없음)
        List<Place> existingPlaces = placeRepository.findAllByExternalPlaceIdIn(ids);
        Set<String> existingIds = existingPlaces.stream()
                .map(Place::getExternalPlaceId)
                .collect(Collectors.toSet());

        List<Place> newPlaces = docs.stream()
                .filter(d -> !existingIds.contains(d.getId()))
                .map(this::saveFromKakao)
                .toList();

        log.info("[Place] 후보 저장: 신규={}개 기존={}개", newPlaces.size(), existingPlaces.size());
        return Stream.concat(existingPlaces.stream(), newPlaces.stream()).toList();
    }

    // ── 비동기 영업시간 보강 진입점 (PlaceEnrichmentEventListener에서 호출) ─

    // [enrichment 비활성화] 이벤트 발행이 모두 주석 처리되어 정상 경로에선 호출되지 않지만,
    // 인터페이스 시그니처를 유지하기 위해 메서드는 남기고 본문만 no-op으로 둔다.
    // 영업시간 보강 재도입 시 아래 원본 본문 주석 해제 + 위 이벤트 발행도 해제.

    @Override
    @Transactional
    public void enrichOpeningHoursByPlaceId(Long placeId) {
        log.debug("[Async/Enrich] 비활성화 상태 — no-op placeId={}", placeId);
        /*
        Place place = placeRepository.findById(placeId).orElse(null);
        if (place == null) {
            log.warn("[Async/Enrich] Place not found placeId={}", placeId);
            return;
        }
        if (place.getGooglePlaceId() != null && !isHoursExpired(place)) {
            log.info("[Async/Enrich] 이미 캐시 유효 → 스킵 placeId={}", placeId);
            return;
        }
        enrichWithGoogleTextSearch(place, place.getName());
        */
    }

    @Override
    @Transactional
    public void refreshOpeningHoursByPlaceId(Long placeId) {
        log.debug("[Async/Refresh] 비활성화 상태 — no-op placeId={}", placeId);
        /*
        Place place = placeRepository.findById(placeId).orElse(null);
        if (place == null) {
            log.warn("[Async/Refresh] Place not found placeId={}", placeId);
            return;
        }
        if (place.getGooglePlaceId() == null) {
            // 신규로 떨어졌을 수도 — INITIAL 흐름 활용
            enrichWithGoogleTextSearch(place, place.getName());
            return;
        }
        if (!isHoursExpired(place)) {
            log.info("[Async/Refresh] TTL 만료 아님 → 스킵 placeId={}", placeId);
            return;
        }
        refreshWithPlaceDetails(place);
        */
    }

    @Override
    @Transactional
    public void enrichCandidatesByPlaceIds(List<Long> placeIds, String placeText,
                                           double latitude, double longitude) {
        log.debug("[Async/Batch] 비활성화 상태 — no-op placeText='{}' size={}",
                placeText, placeIds != null ? placeIds.size() : 0);
        /*
        if (placeIds == null || placeIds.isEmpty()) return;
        List<Place> places = placeRepository.findAllById(placeIds);
        if (places.isEmpty()) {
            log.warn("[Async/Batch] 모든 placeId 미존재 (size={}) → 스킵", placeIds.size());
            return;
        }
        batchEnrichOpeningHours(places, placeText, latitude, longitude);
        */
    }

    // ── Google 보강 (SPECIFIC 신규) ──────────────────────────────────────────

    private static final double SPECIFIC_ENRICH_MAX_DIST_M = 500.0;

    /**
     * Phone-first lookup — 카카오 phone이 있을 때 가장 정확.
     * Google searchText의 textQuery에 정규화된 phone 값을 그대로 넣어 검색.
     * Google은 phone 검색 시 매칭 결과를 1순위로 거의 unique하게 반환한다.
     *
     * @return phone이 일치하는 GooglePlace 또는 null (매칭 실패 시)
     */
    private GooglePlace phoneBasedLookup(Place place, String normalizedPhone, String kakaoName) {
        // [enrichment 비활성화] Google API 호출 금지. 본문 보존.
        return null;
        /*
        try {
            GoogleTextSearchRequest request = GoogleTextSearchRequest.builder()
                    .textQuery(normalizedPhone)
                    .pageSize(3)
                    .languageCode("ko")
                    .build();
            GoogleNearbySearchResponse response = googlePlacesClient.searchText(request).block();
            if (response == null || response.getPlaces() == null || response.getPlaces().isEmpty()) {
                log.info("[Google/Phone] 결과 없음: phone={} (이름 기반으로 fallback)", normalizedPhone);
                return null;
            }

            for (GooglePlace gp : response.getPlaces()) {
                String gpPhone = normalizePhone(gp.getNationalPhoneNumber());
                if (gpPhone == null) continue;
                if (!gpPhone.equals(normalizedPhone)
                        && !gpPhone.endsWith(normalizedPhone)
                        && !normalizedPhone.endsWith(gpPhone)) {
                    continue;
                }

                String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "?";

                if (gp.getLocation() != null) {
                    double dist = GeoUtils.distanceMeters(place.getLatitude(), place.getLongitude(),
                            gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
                    if (dist > 300.0) {
                        log.warn("[Google/Phone] 전화 일치하지만 거리 초과 ({}m): kakao='{}' google='{}'",
                                (int) dist, kakaoName, gpName);
                        continue;
                    }
                }

                double nameSim = PlaceNameSimilarity.similarity(kakaoName, gpName);
                if (nameSim < 0.2) {
                    log.warn("[Google/Phone] 전화 일치하지만 이름 차이 큼 (유사도={}): kakao='{}' google='{}'",
                            String.format("%.2f", nameSim), kakaoName, gpName);
                    continue;
                }

                log.info("[Google/Phone] 전화번호 매칭: '{}' phone={} 유사도={}",
                        kakaoName, normalizedPhone, String.format("%.2f", nameSim));
                return gp;
            }
            log.info("[Google/Phone] phone 일치 결과 없음: phone={} (이름 기반으로 fallback)", normalizedPhone);
            return null;
        } catch (Exception e) {
            log.warn("[Google/Phone] 검색 실패 phone={}: {}", normalizedPhone, e.getMessage());
            return null;
        }
        */
    }

    /**
     * 이름 기반 lookup + 점수 best 선택.
     * 점수: (거리 가까울수록 높음) * WEIGHT_DISTANCE + (이름 유사도) * WEIGHT_NAME.
     * 카테고리 cross-check 통과 + 이름 유사도 임계값 통과 + 거리 임계값 통과한 후보 중 최고점.
     */
    private GooglePlace nameBasedLookup(Place place, String kakaoName, String kakaoPhoneFallback) {
        // [enrichment 비활성화] Google API 호출 금지. 본문 보존.
        return null;
        /*
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
            log.warn("[Google/Name] 결과 없음: '{}'", kakaoName);
            return null;
        }

        log.info("[Google/Name] 후보 {}개 점수 평가: '{}'", response.getPlaces().size(), kakaoName);
        return pickBestByScore(response.getPlaces(), place, kakaoName, kakaoPhoneFallback);
        */
    }

    /**
     * 후보들을 카테고리 호환 + 이름 유사도 + 거리 임계값으로 필터링한 뒤,
     * 점수 가중합으로 최고점 1개 선택.
     * Phone fast-path가 있으면 phone 일치 후보를 무조건 우선.
     */
    private GooglePlace pickBestByScore(
            List<GooglePlace> candidates,
            Place place,
            String kakaoName,
            String kakaoPhone) {
        // [enrichment 비활성화] Google 매칭 휴리스틱 일시 중단. 본문 보존.
        return null;
        /*
        if (kakaoPhone != null) {
            for (GooglePlace gp : candidates) {
                String gpPhone = normalizePhone(gp.getNationalPhoneNumber());
                if (gpPhone == null) continue;
                if (gpPhone.equals(kakaoPhone)
                        || gpPhone.endsWith(kakaoPhone)
                        || kakaoPhone.endsWith(gpPhone)) {
                    log.info("[Google/Name] 부가 phone 일치 → 즉시 확정: phone={}", kakaoPhone);
                    return gp;
                }
            }
        }

        GooglePlace best = null;
        double bestScore = 0.0;
        for (GooglePlace gp : candidates) {
            String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "";

            // 1. 좌표 검증
            if (gp.getLocation() == null) {
                log.debug("[Google/Name] 좌표 없음: '{}'", gpName);
                continue;
            }
            double dist = GeoUtils.distanceMeters(place.getLatitude(), place.getLongitude(),
                    gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
            if (dist > SPECIFIC_ENRICH_MAX_DIST_M) {
                log.debug("[Google/Name] 거리 초과 ({}m): '{}'", (int) dist, gpName);
                continue;
            }

            // 2. 카테고리 cross-check
            if (!KakaoGoogleCategoryMapping.isCompatible(
                    place.getCategoryGroupCode(), gp.getPrimaryType())) {
                log.info("[Google/Name] 카테고리 불일치 차단: kakao={} google={} ('{}')",
                        place.getCategoryGroupCode(), gp.getPrimaryType(), gpName);
                continue;
            }

            // 3. 이름 유사도
            double nameSim = PlaceNameSimilarity.similarity(kakaoName, gpName);
            if (nameSim < PlaceNameSimilarity.DEFAULT_MIN_SIMILARITY) {
                log.info("[Google/Name] 이름 유사도 미달 ({}): kakao='{}' google='{}'",
                        String.format("%.2f", nameSim), kakaoName, gpName);
                continue;
            }

            // 4. 점수 계산
            double distScore = 1.0 - (dist / SPECIFIC_ENRICH_MAX_DIST_M);
            double score = WEIGHT_DISTANCE * distScore + WEIGHT_NAME * nameSim;
            log.info("[Google/Name] 후보: '{}' 거리={}m 유사도={} 점수={}",
                    gpName, (int) dist,
                    String.format("%.2f", nameSim), String.format("%.2f", score));
            if (score > bestScore) {
                bestScore = score;
                best = gp;
            }
        }
        if (best != null) {
            log.info("[Google/Name] best 선택: '{}' 점수={}",
                    best.getDisplayName() != null ? best.getDisplayName().getText() : "?",
                    String.format("%.2f", bestScore));
        }
        return best;
        */
    }

    private void enrichWithGoogleTextSearch(Place place, String kakaoName) {
        // [enrichment 비활성화] 본문 보존.
        /*
        log.info("[Google/TextSearch] SPECIFIC 보강 시작: '{}' lat={} lon={}",
                kakaoName, place.getLatitude(), place.getLongitude());
        try {
            String kakaoPhone = normalizePhone(place.getPhone());
            GooglePlace matched = null;
            if (kakaoPhone != null) {
                matched = phoneBasedLookup(place, kakaoPhone, kakaoName);
            }

            if (matched == null) {
                matched = nameBasedLookup(place, kakaoName, kakaoPhone);
            }

            if (matched == null) {
                log.warn("[Google/TextSearch] 매칭 실패: '{}'", kakaoName);
                return;
            }

            String gpName = matched.getDisplayName() != null ? matched.getDisplayName().getText() : "?";
            boolean hasHours = matched.getRegularOpeningHours() != null;
            log.info("[Google/TextSearch] 매칭 확정: kakao='{}' ↔ google='{}' type={} status={} hasHours={}",
                    kakaoName, gpName, matched.getPrimaryType(), matched.getBusinessStatus(), hasHours);

            place.enrichGoogleData(matched.getId(), serializeHours(matched), matched.getBusinessStatus());
            saveOpeningPeriods(place.getId(), matched.getRegularOpeningHours());
        } catch (Exception e) {
            log.warn("[Google/TextSearch] SPECIFIC 보강 실패 (placeId={})", place.getId(), e);
        }
        */
    }

    // ── Google 갱신 (SPECIFIC TTL 만료) ─────────────────────────────────────

    private boolean isHoursExpired(Place place) {
        if (place.getHoursFetchedAt() == null) return true;
        return place.getHoursFetchedAt()
                .isBefore(OffsetDateTime.now().minusDays(OPENING_HOURS_TTL_DAYS));
    }

    private void refreshWithPlaceDetails(Place place) {
        // [enrichment 비활성화] 본문 보존.
        /*
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
            log.warn("[Google/Details] 갱신 실패 (placeId={})", place.getId(), e);
        }
        */
    }

    // ── Google 일괄 보강 (GENERIC) ───────────────────────────────────────────

    private void batchEnrichOpeningHours(List<Place> places, String placeText,
                                         double latitude, double longitude) {
        // [enrichment 비활성화] 본문 보존.
        /*
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

            // 매칭 점수 누적 — 동일 카카오 후보가 여러 구글 결과에 매핑될 가능성 차단,
            // 가장 점수 높은 1개만 채택 (one-to-one 매칭)
            Map<Long, ScoredMatch> bestPerPlace = new HashMap<>();
            int filtered = 0;

            for (GooglePlace gp : response.getPlaces()) {
                String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "?";

                if (gp.getLocation() == null) {
                    log.debug("[Google/Batch] 좌표 없음: '{}'", gpName);
                    continue;
                }
                if (gp.getRegularOpeningHours() == null) {
                    log.debug("[Google/Batch] 영업시간 없음: '{}'", gpName);
                    continue;
                }

                // 후보 카카오 Place 중 거리 + 카테고리 + 이름 유사도 모두 만족하는 best 선정
                Place bestPlace = null;
                double bestScore = 0.0;
                double bestDist = 0.0;
                double bestNameSim = 0.0;
                for (Place p : places) {
                    double dist = GeoUtils.distanceMeters(p.getLatitude(), p.getLongitude(),
                            gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
                    if (dist > COORD_MATCH_THRESHOLD_M) continue;
                    if (!KakaoGoogleCategoryMapping.isCompatible(
                            p.getCategoryGroupCode(), gp.getPrimaryType())) continue;
                    double nameSim = PlaceNameSimilarity.similarity(p.getName(), gpName);
                    if (nameSim < PlaceNameSimilarity.DEFAULT_MIN_SIMILARITY) continue;

                    double distScore = 1.0 - (dist / COORD_MATCH_THRESHOLD_M);
                    double score = WEIGHT_DISTANCE * distScore + WEIGHT_NAME * nameSim;
                    if (score > bestScore) {
                        bestScore = score;
                        bestPlace = p;
                        bestDist = dist;
                        bestNameSim = nameSim;
                    }
                }

                if (bestPlace == null) {
                    log.debug("[Google/Batch] 매칭 후보 없음: google='{}'", gpName);
                    filtered++;
                    continue;
                }

                // 더 높은 점수가 이미 등록되어 있으면 건너뛰기
                ScoredMatch existing = bestPerPlace.get(bestPlace.getId());
                if (existing != null && existing.score >= bestScore) {
                    log.debug("[Google/Batch] 더 좋은 매칭 이미 존재: kakao='{}'", bestPlace.getName());
                    continue;
                }
                bestPerPlace.put(bestPlace.getId(),
                        new ScoredMatch(bestPlace, gp, bestScore, bestDist, bestNameSim));
            }

            // 확정된 best 매칭만 영업시간 적용
            int matched = 0;
            for (ScoredMatch m : bestPerPlace.values()) {
                String gpName = m.gp.getDisplayName() != null ? m.gp.getDisplayName().getText() : "?";
                log.info("[Google/Batch] 매칭 확정: kakao='{}' ↔ google='{}' 거리={}m 유사도={} 점수={}",
                        m.place.getName(), gpName, (int) m.dist,
                        String.format("%.2f", m.nameSim), String.format("%.2f", m.score));
                m.place.enrichGoogleData(m.gp.getId(), serializeHours(m.gp), m.gp.getBusinessStatus());
                saveOpeningPeriods(m.place.getId(), m.gp.getRegularOpeningHours());
                matched++;
            }
            log.info("[Google/Batch] 완료: query='{}' 매칭={}개 필터링={}개 (총 google={}개, 카카오 후보={}개)",
                    placeText, matched, filtered, response.getPlaces().size(), places.size());
        } catch (Exception e) {
            log.warn("[Google/Batch] 실패 ({}): {}", placeText, e.getMessage());
        }
        */
    }

    // ── Google TextSearch fallback (SPECIFIC 카카오 실패 시) ─────────────────

    /**
     * 카카오 검색 실패 fallback에서 Google 결과 중 best 선택.
     * 카카오 메타가 없어 카테고리 cross-check 불가 → 이름 유사도 + 거리만 사용.
     * 좌표가 없으면 이름 유사도만으로 판단.
     */
    private GooglePlace pickBestFallback(
            List<GooglePlace> candidates, String placeText,
            Double userLat, Double userLng) {
        // [enrichment 비활성화] 본문 보존.
        return null;
        /*
        GooglePlace best = null;
        double bestScore = 0.0;
        for (GooglePlace gp : candidates) {
            String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : "";
            double nameSim = PlaceNameSimilarity.similarity(placeText, gpName);
            if (nameSim < PlaceNameSimilarity.DEFAULT_MIN_SIMILARITY) {
                log.info("[Google/TextSearch] 이름 유사도 미달 ({}): '{}'",
                        String.format("%.2f", nameSim), gpName);
                continue;
            }
            double score = nameSim;
            if (gp.getLocation() != null && userLat != null && userLng != null) {
                double dist = GeoUtils.distanceMeters(userLat, userLng,
                        gp.getLocation().getLatitude(), gp.getLocation().getLongitude());
                if (dist > SPECIFIC_ENRICH_MAX_DIST_M) {
                    log.info("[Google/TextSearch] 거리 초과 ({}m): '{}'", (int) dist, gpName);
                    continue;
                }
                double distScore = 1.0 - (dist / SPECIFIC_ENRICH_MAX_DIST_M);
                score = WEIGHT_DISTANCE * distScore + WEIGHT_NAME * nameSim;
            }
            log.info("[Google/TextSearch] 후보: '{}' 유사도={} 점수={}",
                    gpName, String.format("%.2f", nameSim), String.format("%.2f", score));
            if (score > bestScore) {
                bestScore = score;
                best = gp;
            }
        }
        return best;
        */
    }

    private Optional<Place> resolveViaGoogleTextSearch(String placeText, Double latitude, Double longitude) {
        // [enrichment 비활성화] 본문 보존. 호출처(SPECIFIC fallback) 이미 비활성화됨.
        return Optional.empty();
        /*
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

            // pageSize 늘려 점수 평가 후보 확보
            builder.pageSize(5);
            GoogleNearbySearchResponse response = googlePlacesClient
                    .searchText(builder.build())
                    .block();

            if (response == null || response.getPlaces() == null || response.getPlaces().isEmpty()) {
                log.warn("[Google/TextSearch] 결과 없음: '{}'", placeText);
                return Optional.empty();
            }

            log.info("[Google/TextSearch] 후보 {}개 점수 평가: '{}'", response.getPlaces().size(), placeText);
            GooglePlace gp = pickBestFallback(response.getPlaces(), placeText, latitude, longitude);
            if (gp == null) {
                log.warn("[Google/TextSearch] 매칭 가능한 후보 없음 (이름 유사도/거리 미달): '{}'", placeText);
                return Optional.empty();
            }

            String gpName = gp.getDisplayName() != null ? gp.getDisplayName().getText() : placeText;
            Optional<Place> existingOpt = placeRepository.findByExternalPlaceId(gp.getId());
            boolean isNew = existingOpt.isEmpty();
            log.info("[Google/TextSearch] 장소 {}: '{}' status={} hasHours={}",
                    isNew ? "신규 저장" : "DB 캐시 hit",
                    gpName, gp.getBusinessStatus(), gp.getRegularOpeningHours() != null);

            Place place = existingOpt.orElseGet(() -> {
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
                        .hoursFetchedAt(hoursJson != null ? OffsetDateTime.now() : null)
                        .build());
            });

            saveOpeningPeriods(place.getId(), gp.getRegularOpeningHours());
            log.info("[Google/TextSearch] 완료: place.id={}", place.getId());
            return Optional.of(place);
        } catch (Exception e) {
            log.error("[Google/TextSearch] 실패: '{}' - {}", placeText, e.getMessage());
            return Optional.empty();
        }
        */
    }

    // ── 영업시간 저장 ─────────────────────────────────────────────────────────

    private void saveOpeningPeriods(Long placeId, GoogleOpeningHours hours) {
        // [enrichment 비활성화] 본문 보존.
        /*
        if (hours == null) {
            log.info("[OpeningHours] regularOpeningHours=null → place.id={} 저장 스킵", placeId);
            return;
        }
        OffsetDateTime now = OffsetDateTime.now();
        List<PlaceOpeningPeriod> periods = OpeningHoursParser.parse(placeId, hours, now);
        if (periods.isEmpty()) {
            log.info("[OpeningHours] 파싱 결과 0개 → place.id={} 저장 스킵", placeId);
            return;
        }
        openingPeriodRepository.deleteAllByPlaceId(placeId);
        openingPeriodRepository.saveAll(periods);
        log.info("[OpeningHours] place.id={} → {}개 period 저장 완료", placeId, periods.size());
        */
    }

    // ── 공통 유틸 ────────────────────────────────────────────────────────────

    /** GENERIC 배치 매칭에서 카카오 ↔ 구글 1:1 best 점수 추적용 (static + 직접 필드). */
    private static final class ScoredMatch {
        final Place place;
        final GooglePlace gp;
        final double score;
        final double dist;
        final double nameSim;

        ScoredMatch(Place place, GooglePlace gp, double score, double dist, double nameSim) {
            this.place = place;
            this.gp = gp;
            this.score = score;
            this.dist = dist;
            this.nameSim = nameSim;
        }
    }

    private String serializeHours(GooglePlace gp) {
        // [enrichment 비활성화] 본문 보존.
        return null;
        /*
        if (gp.getRegularOpeningHours() == null) return null;
        try {
            return objectMapper.writeValueAsString(gp.getRegularOpeningHours());
        } catch (JsonProcessingException e) {
            log.warn("[OpeningHours] 직렬화 실패: {}", e.getMessage());
            return null;
        }
        */
    }

    private static String toLon(Double longitude) {
        return longitude != null ? String.valueOf(longitude) : null;
    }

    private static String toLat(Double latitude) {
        return latitude != null ? String.valueOf(latitude) : null;
    }

    /**
     * 좌표 값이 WGS84 유효 범위 내인지 검증.
     * null은 호출자별로 의미가 다르므로(SPECIFIC: 허용, GENERIC: 차단) 여기서는 통과시킨다.
     * 범위를 벗어난 값(예: lat=95)이 외부 API에 흘러가 4xx 발생하는 케이스 방어용.
     */
    private static boolean isCoordRangeValid(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) return true;
        return Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180;
    }
}
