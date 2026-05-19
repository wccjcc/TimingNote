package com.timingnote.api.domain.place.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.repository.PlaceOpeningPeriodRepository;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.infra.client.google.GooglePlacesClient;
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
import org.springframework.context.ApplicationEventPublisher;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaceServiceImplTest {

    @Mock
    private KakaoLocalClient kakaoLocalClient;

    @Mock
    private GooglePlacesClient googlePlacesClient;

    @Mock
    private PlaceRepository placeRepository;

    @Mock
    private PlaceOpeningPeriodRepository openingPeriodRepository;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    @Mock
    private PlaceSearchCache placeSearchCache;

    private SimpleMeterRegistry registry;
    private PlaceServiceImpl service;

    @BeforeEach
    void setUp() {
        registry = new SimpleMeterRegistry();
        @SuppressWarnings("unchecked")
        ObjectProvider<MeterRegistry> registryProvider = mock(ObjectProvider.class);
        when(registryProvider.getIfAvailable()).thenReturn(registry);
        service = new PlaceServiceImpl(
                kakaoLocalClient,
                googlePlacesClient,
                placeRepository,
                openingPeriodRepository,
                new ObjectMapper(),
                eventPublisher,
                placeSearchCache,
                new PlaceCacheMetrics(registryProvider)
        );
    }

    @Test
    @SuppressWarnings("unchecked")
    void searchAndStoreAll_recordsKakaoLoad_whenCacheLoaderRuns() {
        // given
        when(placeSearchCache.getOrLoadSearch(eq("약국"), eq(35.1483), eq(126.9156), any()))
                .thenAnswer(invocation -> {
                    Supplier<List<PlaceSearchItemResponse>> loader = invocation.getArgument(3);
                    return loader.get();
                });
        when(kakaoLocalClient.searchByKeyword("약국", "126.9156", "35.1483"))
                .thenReturn(Mono.just(new KakaoLocalSearchResponse()));

        // when
        PlaceService.SearchResult result = service.searchAndStoreAll("약국", 35.1483, 126.9156);

        // then
        assertThat(result.searchItems()).isEmpty();
        assertThat(result.storedPlaces()).isEmpty();
        assertThat(registry.counter("place.kakao.search.load").count()).isEqualTo(1.0);
    }
}
