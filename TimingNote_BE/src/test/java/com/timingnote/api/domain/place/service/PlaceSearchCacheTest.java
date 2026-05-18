package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaceSearchCacheTest {

    private static final String SEARCH_KEY = "places:v1:search:약국:3515:12692";
    private static final String SEARCH_LOCK_KEY = "places:v1:lock:search:약국:3515:12692";
    private static final String GEO_KEY = "places:v1:geo:105445:380747";
    private static final Duration SEARCH_TTL_BASE = Duration.ofDays(7);
    private static final Duration SEARCH_TTL_MIN = SEARCH_TTL_BASE.minusSeconds(SEARCH_TTL_BASE.toSeconds() / 10);
    private static final Duration SEARCH_TTL_MAX = SEARCH_TTL_BASE.plusSeconds(SEARCH_TTL_BASE.toSeconds() / 10);
    private static final Duration GEO_TTL_BASE = Duration.ofDays(7);
    private static final Duration GEO_TTL_MIN = GEO_TTL_BASE.minusSeconds(GEO_TTL_BASE.toSeconds() / 10);
    private static final Duration GEO_TTL_MAX = GEO_TTL_BASE.plusSeconds(GEO_TTL_BASE.toSeconds() / 10);

    @Mock
    private StringRedisTemplate redis;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private SimpleMeterRegistry registry;
    private PlaceSearchCache cache;

    @BeforeEach
    void setUp() {
        registry = new SimpleMeterRegistry();
        cache = new PlaceSearchCache(redis, new ObjectMapper(), new PlaceCacheMetrics(registry));
        when(redis.opsForValue()).thenReturn(valueOperations);
    }

    @Test
    void getOrLoadSearch_recordsHit_whenCachedValueExists() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenReturn("[]");
        AtomicBoolean loaderCalled = new AtomicBoolean(false);

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156,
                () -> {
                    loaderCalled.set(true);
                    return List.of();
                }
        );

        // then
        assertThat(result).isEmpty();
        assertThat(loaderCalled).isFalse();
        assertThat(counter("place.cache.search.hit")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.miss")).isZero();
        verify(valueOperations, never()).set(eq(SEARCH_KEY), eq("[]"), any(Duration.class));
    }

    @Test
    void getOrLoadSearch_recordsMiss_whenCacheIsEmpty() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenReturn(null);
        when(valueOperations.setIfAbsent(eq(SEARCH_LOCK_KEY), anyString(), eq(Duration.ofSeconds(5))))
                .thenReturn(true);

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156, List::of
        );

        // then
        assertThat(result).isEmpty();
        assertThat(counter("place.cache.search.hit")).isZero();
        assertThat(counter("place.cache.search.miss")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.lock.acquired")).isEqualTo(1.0);
        ArgumentCaptor<Duration> ttlCaptor = ArgumentCaptor.forClass(Duration.class);
        verify(valueOperations).set(eq(SEARCH_KEY), eq("[]"), ttlCaptor.capture());
        assertThat(ttlCaptor.getValue())
                .isGreaterThanOrEqualTo(SEARCH_TTL_MIN)
                .isLessThanOrEqualTo(SEARCH_TTL_MAX);
    }

    @Test
    void getOrLoadSearch_waitsForLockAndReturnsCachedValue_whenAnotherRequestStoresCache() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenReturn(null, "[]");
        when(valueOperations.setIfAbsent(eq(SEARCH_LOCK_KEY), anyString(), eq(Duration.ofSeconds(5))))
                .thenReturn(false);
        AtomicBoolean loaderCalled = new AtomicBoolean(false);

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156,
                () -> {
                    loaderCalled.set(true);
                    return List.of();
                }
        );

        // then
        assertThat(result).isEmpty();
        assertThat(loaderCalled).isFalse();
        assertThat(counter("place.cache.search.lock.wait")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.hit")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.miss")).isZero();
        verify(valueOperations, never()).set(eq(SEARCH_KEY), eq("[]"), any(Duration.class));
    }

    @Test
    void getOrLoadSearch_fallsBackToLoader_whenLockWaitDoesNotFillCache() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenReturn(null);
        when(valueOperations.setIfAbsent(eq(SEARCH_LOCK_KEY), anyString(), eq(Duration.ofSeconds(5))))
                .thenReturn(false);

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156, List::of
        );

        // then
        assertThat(result).isEmpty();
        assertThat(counter("place.cache.search.lock.wait")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.lock.fallback")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.miss")).isEqualTo(1.0);
        ArgumentCaptor<Duration> ttlCaptor = ArgumentCaptor.forClass(Duration.class);
        verify(valueOperations).set(eq(SEARCH_KEY), eq("[]"), ttlCaptor.capture());
        assertThat(ttlCaptor.getValue())
                .isGreaterThanOrEqualTo(SEARCH_TTL_MIN)
                .isLessThanOrEqualTo(SEARCH_TTL_MAX);
    }

    @Test
    void getOrLoadSearch_bypassesCache_whenRedisGetFails() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenThrow(new RedisConnectionFailureException("redis down"));
        AtomicBoolean loaderCalled = new AtomicBoolean(false);

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156,
                () -> {
                    loaderCalled.set(true);
                    return List.of();
                }
        );

        // then
        assertThat(result).isEmpty();
        assertThat(loaderCalled).isTrue();
        assertThat(counter("place.cache.search.redis.error")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.miss")).isZero();
    }

    @Test
    void getOrLoadSearch_returnsFreshResult_whenRedisSetFails() {
        // given
        when(valueOperations.get(SEARCH_KEY)).thenReturn(null);
        when(valueOperations.setIfAbsent(eq(SEARCH_LOCK_KEY), anyString(), eq(Duration.ofSeconds(5))))
                .thenReturn(true);
        doThrow(new RedisConnectionFailureException("redis down"))
                .when(valueOperations).set(eq(SEARCH_KEY), eq("[]"), any(Duration.class));

        // when
        List<PlaceSearchItemResponse> result = cache.getOrLoadSearch(
                "약국", 35.1483, 126.9156, List::of
        );

        // then
        assertThat(result).isEmpty();
        assertThat(counter("place.cache.search.miss")).isEqualTo(1.0);
        assertThat(counter("place.cache.search.redis.error")).isEqualTo(1.0);
    }

    @Test
    void getOrLoadReverseGeocode_storesWithJitteredTtl_whenCacheIsEmpty() {
        // given
        when(valueOperations.get(GEO_KEY)).thenReturn(null);

        // when
        String result = cache.getOrLoadReverseGeocode(
                35.1483, 126.9156, () -> "광주 동구 테스트로"
        );

        // then
        assertThat(result).isEqualTo("광주 동구 테스트로");
        assertThat(counter("place.cache.geo.miss")).isEqualTo(1.0);
        ArgumentCaptor<Duration> ttlCaptor = ArgumentCaptor.forClass(Duration.class);
        verify(valueOperations).set(eq(GEO_KEY), eq("광주 동구 테스트로"), ttlCaptor.capture());
        assertThat(ttlCaptor.getValue())
                .isGreaterThanOrEqualTo(GEO_TTL_MIN)
                .isLessThanOrEqualTo(GEO_TTL_MAX);
    }

    private double counter(String name) {
        return registry.counter(name).count();
    }
}
