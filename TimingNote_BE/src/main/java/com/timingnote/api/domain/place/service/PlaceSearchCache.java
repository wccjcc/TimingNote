package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.function.Supplier;

/**
 * 카카오 Local API 응답을 Redis에 캐시하는 컴포넌트.
 *
 * <p>설계 결정:
 * <ul>
 *   <li><b>좌표 grid 키 정규화</b>: lat/lng를 양자화해 동일 지역 사용자들이 캐시 공유.
 *       search는 1km grid(multiplier 100), reverse geocode는 30m grid(multiplier 3000).
 *       정확도 손실은 거의 없고(grid 내 매장 정렬 차이 무시 가능) 인기 검색어 quota 절감 효과 큼.</li>
 *   <li><b>TTL</b>: search 7일, reverse geocode 24시간. 카카오 데이터 stale 위험(1주일 ~0.4%) 대비
 *       hit 효율의 sweet spot.</li>
 *   <li><b>JSON 직렬화</b>: {@link StringRedisTemplate} + {@link ObjectMapper} 조합. Spring Cache
 *       추상화(@Cacheable) 대신 직접 호출 패턴을 택한 이유는 grid 키 가공·hit/miss 로깅·null 처리를
 *       명시적으로 다루기 위함.</li>
 *   <li><b>Negative caching</b>: reverse geocode 매칭 실패(null)도 24시간 캐시. sentinel 빈 문자열("")로
 *       저장. 좌표가 진짜 주소 없는 곳(해상/사막 등)이면 24시간 안엔 바뀔 일 없음.</li>
 * </ul>
 *
 * <p>키 prefix는 {@code places:*}로 통일해 다른 도메인(알림 쿨다운, 세션 등)과 namespace 분리.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PlaceSearchCache {

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    // ── 키 prefix ─────────────────────────────────────────────────────
    private static final String KEY_PREFIX_SEARCH = "places:search:";
    private static final String KEY_PREFIX_GEO = "places:geo:";
    // reverse geocode 결과가 null(주소 매칭 실패)일 때 캐시에 저장하는 sentinel.
    // get 시 이 값을 만나면 호출자에게는 null을 반환해 negative caching 효과.
    private static final String NEGATIVE_SENTINEL = "";

    // ── grid multiplier ───────────────────────────────────────────────
    // round(coord * multiplier) → grid 키. 한국(위도 37°)에서:
    // - 100: 0.01° ≈ 위도 1.1km / 경도 0.88km → 약 1km grid (keyword search)
    // - 3000: 0.00033° ≈ 30m grid (reverse geocode)
    private static final int GRID_MULTIPLIER_SEARCH = 100;
    private static final int GRID_MULTIPLIER_GEO = 3000;

    // ── TTL ────────────────────────────────────────────────────────────
    private static final Duration TTL_SEARCH = Duration.ofDays(7);
    private static final Duration TTL_GEO = Duration.ofHours(24);

    // ─────────────────────────────────────────────────────────────────
    // Keyword search
    // ─────────────────────────────────────────────────────────────────

    /**
     * 키워드 검색 캐시 조회 후 miss면 loader 실행 + 결과 저장.
     *
     * @param query 검색어 (정규화: trim + lowercase)
     * @param lat/lng 사용자 좌표 (null이면 grid 무시, "no-loc"로 키 구성)
     * @param size 결과 개수 (캐시 키 일부)
     * @param sortByDistance 거리순/정확도순 분리 키
     * @param loader miss 시 실행할 카카오 호출 람다
     */
    public List<PlaceSearchItemResponse> getOrLoadSearch(
            String query,
            Double lat,
            Double lng,
            int size,
            boolean sortByDistance,
            Supplier<List<PlaceSearchItemResponse>> loader
    ) {
        final String key = buildSearchKey(query, lat, lng, size, sortByDistance);

        String cached = redis.opsForValue().get(key);
        if (cached != null) {
            try {
                List<PlaceSearchItemResponse> result = objectMapper.readValue(
                        cached, new TypeReference<List<PlaceSearchItemResponse>>() {});
                log.info("[PLACE_CACHE][SEARCH][HIT] key='{}' results={}",
                        key, result.size());
                return result;
            } catch (JsonProcessingException e) {
                // 캐시 손상 — 무효화 후 재호출
                log.warn("[PLACE_CACHE][SEARCH][CORRUPT] key='{}' err={}", key, e.getMessage());
                redis.delete(key);
            }
        }

        List<PlaceSearchItemResponse> fresh = loader.get();
        try {
            String json = objectMapper.writeValueAsString(fresh);
            redis.opsForValue().set(key, json, TTL_SEARCH);
            log.info("[PLACE_CACHE][SEARCH][MISS] key='{}' stored={} ttl={}h",
                    key, fresh.size(), TTL_SEARCH.toHours());
        } catch (JsonProcessingException e) {
            log.warn("[PLACE_CACHE][SEARCH][STORE_FAIL] key='{}' err={}", key, e.getMessage());
            // 저장 실패해도 결과는 반환 (캐시 fail-soft)
        }
        return fresh;
    }

    // ─────────────────────────────────────────────────────────────────
    // Reverse geocode
    // ─────────────────────────────────────────────────────────────────

    /**
     * 역지오코딩 캐시 조회 후 miss면 loader 실행 + 결과 저장.
     * loader 결과가 null이면 sentinel("")로 24시간 negative caching.
     */
    public String getOrLoadReverseGeocode(
            double latitude,
            double longitude,
            Supplier<String> loader
    ) {
        final String key = buildGeoKey(latitude, longitude);

        String cached = redis.opsForValue().get(key);
        if (cached != null) {
            String value = NEGATIVE_SENTINEL.equals(cached) ? null : cached;
            log.info("[PLACE_CACHE][GEO][HIT] key='{}' matched={}",
                    key, value != null);
            return value;
        }

        String fresh = loader.get();
        // null도 sentinel로 저장해서 매칭 실패 좌표 반복 호출 방지
        String toStore = (fresh == null) ? NEGATIVE_SENTINEL : fresh;
        redis.opsForValue().set(key, toStore, TTL_GEO);
        log.info("[PLACE_CACHE][GEO][MISS] key='{}' matched={} ttl={}h",
                key, fresh != null, TTL_GEO.toHours());
        return fresh;
    }

    // ─────────────────────────────────────────────────────────────────
    // 키 생성 — 모든 키는 동일 prefix + grid 정규화
    // ─────────────────────────────────────────────────────────────────

    private String buildSearchKey(String query, Double lat, Double lng, int size, boolean sortByDistance) {
        String q = query.trim().toLowerCase();
        String loc;
        if (lat == null || lng == null) {
            loc = "no-loc";
        } else {
            int gridLat = (int) Math.round(lat * GRID_MULTIPLIER_SEARCH);
            int gridLng = (int) Math.round(lng * GRID_MULTIPLIER_SEARCH);
            loc = gridLat + ":" + gridLng;
        }
        String sort = sortByDistance ? "distance" : "accuracy";
        return KEY_PREFIX_SEARCH + q + ":" + loc + ":" + size + ":" + sort;
    }

    private String buildGeoKey(double lat, double lng) {
        int gridLat = (int) Math.round(lat * GRID_MULTIPLIER_GEO);
        int gridLng = (int) Math.round(lng * GRID_MULTIPLIER_GEO);
        return KEY_PREFIX_GEO + gridLat + ":" + gridLng;
    }
}
