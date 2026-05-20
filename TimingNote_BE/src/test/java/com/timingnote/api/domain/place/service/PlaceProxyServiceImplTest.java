package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.ObjectProvider;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaceProxyServiceImplTest {

    @Mock
    private KakaoLocalClient kakaoLocalClient;

    @Mock
    private KakaoGeoClient kakaoGeoClient;

    @Mock
    private PlaceSearchCache cache;

    private SimpleMeterRegistry registry;
    private PlaceProxyServiceImpl service;

    @BeforeEach
    void setUp() {
        registry = new SimpleMeterRegistry();
        @SuppressWarnings("unchecked")
        ObjectProvider<MeterRegistry> registryProvider = mock(ObjectProvider.class);
        when(registryProvider.getIfAvailable()).thenReturn(registry);
        service = new PlaceProxyServiceImpl(
                kakaoLocalClient,
                kakaoGeoClient,
                cache,
                new PlaceCacheMetrics(registryProvider)
        );
    }

    @Test
    @SuppressWarnings("unchecked")
    void searchByKeyword_recordsKakaoLoad_whenCacheLoaderRuns() {
        // given
        when(cache.getOrLoadSearch(eq("약국"), eq(35.1483), eq(126.9156), any()))
                .thenAnswer(invocation -> {
                    Supplier<List<PlaceSearchItemResponse>> loader = invocation.getArgument(3);
                    return loader.get();
                });
        when(kakaoLocalClient.searchByKeyword("약국", "126.9156", "35.1483"))
                .thenReturn(Mono.just(new KakaoLocalSearchResponse()));

        // when
        List<PlaceSearchItemResponse> result = service.searchByKeyword("약국", 35.1483, 126.9156);

        // then
        assertThat(result).isEmpty();
        assertThat(registry.counter("place.kakao.search.load").count()).isEqualTo(1.0);
    }
}
