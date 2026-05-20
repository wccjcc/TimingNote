package com.timingnote.api.domain.place.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * 장소 캐시(Redis) 및 카카오 API 호출 관련 메트릭을 수집하는 컴포넌트.
 * Micrometer의 Counter를 사용하여 Prometheus 등에서 조회할 수 있도록 한다.
 */
@Component
public class PlaceCacheMetrics {

    private final MeterRegistry registry;

    public PlaceCacheMetrics(ObjectProvider<MeterRegistry> registryProvider) {
        this.registry = registryProvider.getIfAvailable();
    }

    public void searchHit() {
        increment("place.cache.search.hit", "Keyword search cache hit count");
    }

    public void searchMiss() {
        increment("place.cache.search.miss", "Keyword search cache miss count");
    }

    public void searchCorrupt() {
        increment("place.cache.search.corrupt", "Keyword search cache JSON corrupt count");
    }

    public void searchStoreFail() {
        increment("place.cache.search.store.fail", "Keyword search cache JSON store failure count");
    }

    public void searchRedisError() {
        increment("place.cache.search.redis.error", "Keyword search Redis operation error count");
    }

    public void searchLockAcquired() {
        increment("place.cache.search.lock.acquired", "Keyword search stampede lock acquired count");
    }

    public void searchLockWait() {
        increment("place.cache.search.lock.wait", "Keyword search stampede lock wait count");
    }

    public void searchLockFallback() {
        increment("place.cache.search.lock.fallback", "Keyword search stampede lock fallback load count");
    }

    public void kakaoSearchLoad() {
        increment("place.kakao.search.load", "Kakao keyword search load count");
    }

    public void geoHit() {
        increment("place.cache.geo.hit", "Reverse geocode cache hit count");
    }

    public void geoMiss() {
        increment("place.cache.geo.miss", "Reverse geocode cache miss count");
    }

    public void geoRedisError() {
        increment("place.cache.geo.redis.error", "Reverse geocode Redis operation error count");
    }

    public void kakaoGeoLoad() {
        increment("place.kakao.geo.load", "Kakao reverse geocode load count");
    }

    private void increment(String name, String description) {
        if (registry != null) {
            Counter.builder(name)
                    .description(description)
                    .register(registry)
                    .increment();
        }
    }
}
