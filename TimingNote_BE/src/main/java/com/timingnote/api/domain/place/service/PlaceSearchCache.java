package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.Collections;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.function.Supplier;

/**
 * 카카오 Local API 응답을 Redis에 캐시하는 컴포넌트.
 *
 * <p>설계 결정:
 * <ul>
 *   <li><b>좌표 grid 키 정규화</b>: lat/lng를 양자화해 동일 지역 사용자들이 캐시 공유.
 *       search는 1km grid(multiplier 100), reverse geocode는 30m grid(multiplier 3000).
 *       정확도 손실은 거의 없고(grid 내 매장 정렬 차이 무시 가능) 인기 검색어 quota 절감 효과 큼.</li>
 *   <li><b>단일 캐시</b>: FE 검색창 경로와 내부 흐름(searchAndStoreAll)이 동일한
 *       {@link PlaceSearchItemResponse} 캐시를 공유한다 ({@code places:v1:search:*}).
 *       categoryName까지 DTO에 포함시켜 raw KakaoDocument와 정보 손실 없음.</li>
 *   <li><b>Key versioning</b>: 캐시 value 구조나 grid 의미가 바뀔 때 Redis에 남은 예전 JSON을
 *       새 코드가 읽지 않도록 {@code places:v1:*} namespace를 둔다.</li>
 *   <li><b>TTL</b>: search/reverse geocode 7일 기준. TTL jitter를 ±10% 범위로 적용해
 *       평균 TTL은 유지하면서 대량 키의 동시 만료를 분산한다.</li>
 *   <li><b>JSON 직렬화</b>: {@link StringRedisTemplate} + {@link ObjectMapper} 조합. Spring Cache
 *       추상화(@Cacheable) 대신 직접 호출 패턴을 택한 이유는 grid 키 가공·hit/miss 로깅·null 처리를
 *       명시적으로 다루기 위함.</li>
 *   <li><b>Negative caching</b>: reverse geocode 매칭 실패(null)도 최대 7일 캐시. sentinel 빈 문자열("")로
 *       저장. 좌표가 진짜 주소 없는 곳이면 짧은 기간 안에 결과가 바뀔 가능성이 낮다.</li>
 * </ul>
 *
 * <p>키 prefix는 {@code places:v1:*}로 통일해 다른 도메인(알림 쿨다운, 세션 등)과 namespace 분리.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PlaceSearchCache {

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;
    private final PlaceCacheMetrics metrics;

    // ── 키 prefix ─────────────────────────────────────────────────────
    private static final String CACHE_VERSION = "v1";
    private static final String KEY_PREFIX_ROOT = "places:" + CACHE_VERSION + ":";
    private static final String KEY_PREFIX_SEARCH = KEY_PREFIX_ROOT + "search:";
    private static final String KEY_PREFIX_SEARCH_LOCK = KEY_PREFIX_ROOT + "lock:search:";
    private static final String KEY_PREFIX_GEO = KEY_PREFIX_ROOT + "geo:";
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
    // search 7일: 카카오 매장 데이터 stale 위험 ~0.4%/주 대비 hit 효율 sweet spot.
    // geo 7일: 도로명 주소는 신축/재개발 외엔 변동 없음 (연 변동률 ~0.4%, 7일 stale ~0.01%).
    //         하루 단위에서 일주일 단위로 늘려 quota 약 7배 절감.
    private static final Duration TTL_SEARCH = Duration.ofDays(7);
    private static final Duration TTL_GEO = Duration.ofDays(7);
    private static final int TTL_JITTER_PERCENT = 10;
    private static final Duration SEARCH_LOCK_TTL = Duration.ofSeconds(5);
    private static final Duration SEARCH_LOCK_WAIT_INTERVAL = Duration.ofMillis(50);
    private static final int SEARCH_LOCK_MAX_WAIT_ATTEMPTS = 10;
    private static final DefaultRedisScript<Long> RELEASE_LOCK_SCRIPT = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class
    );

    // ─────────────────────────────────────────────────────────────────
    // Keyword search — FE/내부 흐름 공용
    // ─────────────────────────────────────────────────────────────────

    /**
     * 키워드 검색 캐시 조회 후 miss면 loader 실행 + 결과 저장.
     * <p>카카오 size는 기본값(15 = max) 고정으로 키에서 제외 — 호출자가 size 지정 불가.
     * <p>sort 분리 키 없음: 우리는 카카오에 sort 파라미터를 전달하지 않고 좌표만 보낸다.
     * 좌표 유무에 따른 응답 차이(거리 가중 accuracy vs 순수 accuracy)는 키의 grid 부분
     * (`3750:12703` vs `no-loc`)이 이미 자연 분리한다.
     *
     * @param query 검색어 (정규화: trim + lowercase)
     * @param lat/lng 사용자 좌표 (null이면 grid 무시, "no-loc"로 키 구성)
     * @param loader miss 시 실행할 카카오 호출 람다
     */
    public List<PlaceSearchItemResponse> getOrLoadSearch(
            String query,
            Double lat,
            Double lng,
            Supplier<List<PlaceSearchItemResponse>> loader
    ) {
        final String key = buildSearchKey(query, lat, lng);

        SearchCacheLookup cached = readSearchCache(key);
        if (cached.hit()) {
            return cached.result();
        }
        if (cached.redisFailed()) {
            return loadSearchWithoutCache(key, loader);
        }

        return loadSearchWithStampedeLock(key, loader);
    }

    private List<PlaceSearchItemResponse> loadSearchWithStampedeLock(
            String key,
            Supplier<List<PlaceSearchItemResponse>> loader
    ) {
        String lockKey = buildSearchLockKey(key);
        String token = UUID.randomUUID().toString();

        Boolean lockAcquired = acquireSearchLock(lockKey, token);
        if (lockAcquired == null) {
            return loadSearchWithoutCache(key, loader);
        }
        if (lockAcquired) {
            metrics.searchLockAcquired();
            try {
                metrics.searchMiss();
                return loadAndStoreSearch(key, loader);
            } finally {
                releaseSearchLock(lockKey, token);
            }
        }

        metrics.searchLockWait();
        for (int attempt = 0; attempt < SEARCH_LOCK_MAX_WAIT_ATTEMPTS; attempt++) {
            sleepForSearchLock();
            SearchCacheLookup cached = readSearchCache(key);
            if (cached.hit()) {
                return cached.result();
            }
            if (cached.redisFailed()) {
                return loadSearchWithoutCache(key, loader);
            }
        }

        metrics.searchLockFallback();
        metrics.searchMiss();
        return loadAndStoreSearch(key, loader);
    }

    private SearchCacheLookup readSearchCache(String key) {
        String cached;
        try {
            cached = redis.opsForValue().get(key);
        } catch (RuntimeException e) {
            metrics.searchRedisError();
            log.warn("[PLACE_CACHE][SEARCH][REDIS_GET_FAIL] keyHash={} err={}",
                    keyFingerprint(key), e.getMessage());
            return SearchCacheLookup.failed();
        }
        if (cached == null) {
            return SearchCacheLookup.miss();
        }

        try {
            List<PlaceSearchItemResponse> result = objectMapper.readValue(
                    cached, new TypeReference<List<PlaceSearchItemResponse>>() {});
            metrics.searchHit();
            log.debug("[PLACE_CACHE][SEARCH][HIT] keyHash={} results={}",
                    keyFingerprint(key), result.size());
            return SearchCacheLookup.hit(result);
        } catch (JsonProcessingException e) {
            metrics.searchCorrupt();
            log.warn("[PLACE_CACHE][SEARCH][CORRUPT] keyHash={} err={}",
                    keyFingerprint(key), e.getMessage());
            try {
                redis.delete(key);
            } catch (RuntimeException redisError) {
                metrics.searchRedisError();
                log.warn("[PLACE_CACHE][SEARCH][REDIS_DELETE_FAIL] keyHash={} err={}",
                        keyFingerprint(key), redisError.getMessage());
            }
            return SearchCacheLookup.miss();
        }
    }

    private List<PlaceSearchItemResponse> loadAndStoreSearch(
            String key,
            Supplier<List<PlaceSearchItemResponse>> loader
    ) {
        List<PlaceSearchItemResponse> fresh = loader.get();
        try {
            String json = objectMapper.writeValueAsString(fresh);
            Duration ttl = withJitter(TTL_SEARCH);
            try {
                redis.opsForValue().set(key, json, ttl);
            } catch (RuntimeException e) {
                metrics.searchRedisError();
                log.warn("[PLACE_CACHE][SEARCH][REDIS_SET_FAIL] keyHash={} err={}",
                        keyFingerprint(key), e.getMessage());
                return fresh;
            }
            log.debug("[PLACE_CACHE][SEARCH][MISS] keyHash={} stored={} ttlSeconds={}",
                    keyFingerprint(key), fresh.size(), ttl.toSeconds());
        } catch (JsonProcessingException e) {
            metrics.searchStoreFail();
            log.warn("[PLACE_CACHE][SEARCH][STORE_FAIL] keyHash={} err={}",
                    keyFingerprint(key), e.getMessage());
            // 저장 실패해도 결과는 반환 (캐시 fail-soft)
        }
        return fresh;
    }

    private List<PlaceSearchItemResponse> loadSearchWithoutCache(
            String key,
            Supplier<List<PlaceSearchItemResponse>> loader
    ) {
        log.warn("[PLACE_CACHE][SEARCH][BYPASS] keyHash={} reason=redis_unavailable",
                keyFingerprint(key));
        return loader.get();
    }

    private Boolean acquireSearchLock(String lockKey, String token) {
        try {
            return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(lockKey, token, SEARCH_LOCK_TTL));
        } catch (RuntimeException e) {
            metrics.searchRedisError();
            log.warn("[PLACE_CACHE][SEARCH][LOCK_ACQUIRE_FAIL] keyHash={} err={}",
                    keyFingerprint(lockKey), e.getMessage());
            return null;
        }
    }

    private void releaseSearchLock(String lockKey, String token) {
        try {
            redis.execute(RELEASE_LOCK_SCRIPT, Collections.singletonList(lockKey), token);
        } catch (RuntimeException e) {
            metrics.searchRedisError();
            log.warn("[PLACE_CACHE][SEARCH][LOCK_RELEASE_FAIL] keyHash={} err={}",
                    keyFingerprint(lockKey), e.getMessage());
        }
    }

    private void sleepForSearchLock() {
        try {
            Thread.sleep(SEARCH_LOCK_WAIT_INTERVAL.toMillis());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while waiting for search cache lock", e);
        }
    }

    private record SearchCacheLookup(List<PlaceSearchItemResponse> result, boolean redisFailed) {

        static SearchCacheLookup hit(List<PlaceSearchItemResponse> result) {
            return new SearchCacheLookup(result, false);
        }

        static SearchCacheLookup miss() {
            return new SearchCacheLookup(null, false);
        }

        static SearchCacheLookup failed() {
            return new SearchCacheLookup(null, true);
        }

        boolean hit() {
            return result != null;
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Reverse geocode
    // ─────────────────────────────────────────────────────────────────

    /**
     * 역지오코딩 캐시 조회 후 miss면 loader 실행 + 결과 저장.
     * loader 결과가 null이면 sentinel("")로 negative caching.
     */
    public String getOrLoadReverseGeocode(
            double latitude,
            double longitude,
            Supplier<String> loader
    ) {
        final String key = buildGeoKey(latitude, longitude);

        String cached;
        try {
            cached = redis.opsForValue().get(key);
        } catch (RuntimeException e) {
            metrics.geoRedisError();
            log.warn("[PLACE_CACHE][GEO][REDIS_GET_FAIL] keyHash={} err={}",
                    keyFingerprint(key), e.getMessage());
            return loader.get();
        }
        if (cached != null) {
            String value = NEGATIVE_SENTINEL.equals(cached) ? null : cached;
            metrics.geoHit();
            log.debug("[PLACE_CACHE][GEO][HIT] keyHash={} matched={}",
                    keyFingerprint(key), value != null);
            return value;
        }

        metrics.geoMiss();
        String fresh = loader.get();
        // null도 sentinel로 저장해서 매칭 실패 좌표 반복 호출 방지
        String toStore = (fresh == null) ? NEGATIVE_SENTINEL : fresh;
        try {
            Duration ttl = withJitter(TTL_GEO);
            redis.opsForValue().set(key, toStore, ttl);
            log.debug("[PLACE_CACHE][GEO][MISS] keyHash={} matched={} ttlSeconds={}",
                    keyFingerprint(key), fresh != null, ttl.toSeconds());
        } catch (RuntimeException e) {
            metrics.geoRedisError();
            log.warn("[PLACE_CACHE][GEO][REDIS_SET_FAIL] keyHash={} err={}",
                    keyFingerprint(key), e.getMessage());
            return fresh;
        }
        return fresh;
    }

    private Duration withJitter(Duration baseTtl) {
        long baseSeconds = baseTtl.toSeconds();
        long jitterSeconds = baseSeconds * TTL_JITTER_PERCENT / 100;
        if (jitterSeconds <= 0) {
            return baseTtl;
        }
        long offsetSeconds = ThreadLocalRandom.current().nextLong(-jitterSeconds, jitterSeconds + 1);
        return Duration.ofSeconds(baseSeconds + offsetSeconds);
    }

    private static String keyFingerprint(String key) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(key.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest, 0, 8);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 digest unavailable", e);
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // 키 생성 — 모든 키는 동일 prefix + grid 정규화
    // ─────────────────────────────────────────────────────────────────

    private String buildSearchKey(String query, Double lat, Double lng) {
        // 띄어쓰기까지 제거해 "스타벅스 강남점"·"스타벅스강남점"·"스타벅스  강남점"이 같은 키를 가지도록 정규화.
        // 카카오 호출 시에는 사용자 원문을 그대로 전달(검색 정확도 보존) — 키만 정규화한다.
        String q = query.trim().toLowerCase().replaceAll("\\s+", "");
        String loc;
        if (lat == null || lng == null) {
            loc = "no-loc";
        } else {
            int gridLat = (int) Math.round(lat * GRID_MULTIPLIER_SEARCH);
            int gridLng = (int) Math.round(lng * GRID_MULTIPLIER_SEARCH);
            loc = gridLat + ":" + gridLng;
        }
        return KEY_PREFIX_SEARCH + q + ":" + loc;
    }

    private String buildSearchLockKey(String searchKey) {
        String searchKeySuffix = searchKey.substring(KEY_PREFIX_SEARCH.length());
        return KEY_PREFIX_SEARCH_LOCK + searchKeySuffix;
    }

    private String buildGeoKey(double lat, double lng) {
        int gridLat = (int) Math.round(lat * GRID_MULTIPLIER_GEO);
        int gridLng = (int) Math.round(lng * GRID_MULTIPLIER_GEO);
        return KEY_PREFIX_GEO + gridLat + ":" + gridLng;
    }
}
