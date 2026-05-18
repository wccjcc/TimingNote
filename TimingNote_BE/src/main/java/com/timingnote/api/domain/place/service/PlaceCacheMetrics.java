package com.timingnote.api.domain.place.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

@Component
public class PlaceCacheMetrics {

    private final Counter searchHit;
    private final Counter searchMiss;
    private final Counter searchCorrupt;
    private final Counter searchStoreFail;
    private final Counter searchRedisError;
    private final Counter searchLockAcquired;
    private final Counter searchLockWait;
    private final Counter searchLockFallback;
    private final Counter kakaoSearchLoad;

    private final Counter geoHit;
    private final Counter geoMiss;
    private final Counter geoRedisError;
    private final Counter kakaoGeoLoad;

    public PlaceCacheMetrics(MeterRegistry registry) {
        this.searchHit = counter(registry, "place.cache.search.hit", "Keyword search cache hit count");
        this.searchMiss = counter(registry, "place.cache.search.miss", "Keyword search cache miss count");
        this.searchCorrupt = counter(registry, "place.cache.search.corrupt", "Keyword search cache JSON corrupt count");
        this.searchStoreFail = counter(registry, "place.cache.search.store.fail", "Keyword search cache JSON store failure count");
        this.searchRedisError = counter(registry, "place.cache.search.redis.error", "Keyword search Redis operation error count");
        this.searchLockAcquired = counter(registry, "place.cache.search.lock.acquired", "Keyword search stampede lock acquired count");
        this.searchLockWait = counter(registry, "place.cache.search.lock.wait", "Keyword search stampede lock wait count");
        this.searchLockFallback = counter(registry, "place.cache.search.lock.fallback", "Keyword search stampede lock fallback load count");
        this.kakaoSearchLoad = counter(registry, "place.kakao.search.load", "Kakao keyword search load count");

        this.geoHit = counter(registry, "place.cache.geo.hit", "Reverse geocode cache hit count");
        this.geoMiss = counter(registry, "place.cache.geo.miss", "Reverse geocode cache miss count");
        this.geoRedisError = counter(registry, "place.cache.geo.redis.error", "Reverse geocode Redis operation error count");
        this.kakaoGeoLoad = counter(registry, "place.kakao.geo.load", "Kakao reverse geocode load count");
    }

    public void searchHit() {
        searchHit.increment();
    }

    public void searchMiss() {
        searchMiss.increment();
    }

    public void searchCorrupt() {
        searchCorrupt.increment();
    }

    public void searchStoreFail() {
        searchStoreFail.increment();
    }

    public void searchRedisError() {
        searchRedisError.increment();
    }

    public void searchLockAcquired() {
        searchLockAcquired.increment();
    }

    public void searchLockWait() {
        searchLockWait.increment();
    }

    public void searchLockFallback() {
        searchLockFallback.increment();
    }

    public void kakaoSearchLoad() {
        kakaoSearchLoad.increment();
    }

    public void geoHit() {
        geoHit.increment();
    }

    public void geoMiss() {
        geoMiss.increment();
    }

    public void geoRedisError() {
        geoRedisError.increment();
    }

    public void kakaoGeoLoad() {
        kakaoGeoLoad.increment();
    }

    private Counter counter(MeterRegistry registry, String name, String description) {
        return Counter.builder(name)
                .description(description)
                .register(registry);
    }
}
