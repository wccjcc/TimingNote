package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoLocalSearchResponse;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.test.util.ReflectionTestUtils;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Optional;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaceServiceImplTest {

    @Mock
    private KakaoLocalClient kakaoLocalClient;

    @Mock
    private PlaceRepository placeRepository;

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
                placeRepository,
                placeSearchCache,
                new PlaceCacheMetrics(registryProvider)
        );
    }

    @Test
    @DisplayName("통합 검색 시 기존 장소의 정보가 다르면 최신 정보로 업데이트(Upsert)해야 한다")
    @SuppressWarnings("unchecked")
    void searchAndStoreAll_updatesExistingPlace() {
        // given
        PlaceSearchItemResponse latestInfo = PlaceSearchItemResponse.builder()
                .id("ID1").placeName("새로운 이름").latitude(37.0).longitude(126.0)
                .categoryName("새로운 카테고리").categoryGroupCode("PM9").categoryGroupName("약국")
                .addressName("새로운 주소").roadAddressName("새로운 도로명").build();

        when(placeSearchCache.getOrLoadSearch(eq("약국"), eq(37.0), eq(126.0), any()))
                .thenReturn(List.of(latestInfo));

        Place existingPlace = Place.builder()
                .id(10L).externalPlaceId("ID1").name("옛날 이름").categoryName("옛날 카테고리").build();
        when(placeRepository.findAllByExternalPlaceIdIn(List.of("ID1")))
                .thenReturn(List.of(existingPlace));

        // when
        service.searchAndStoreAll("약국", 37.0, 126.0);

        // then
        assertThat(existingPlace.getName()).isEqualTo("새로운 이름");
        assertThat(existingPlace.getCategoryName()).isEqualTo("새로운 카테고리");
        assertThat(existingPlace.getAddress()).isEqualTo("새로운 주소");
    }

    @Test
    @DisplayName("좌표 범위 검증 로직이 올바르게 동작해야 한다")
    void isCoordRangeValidTests() {
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(PlaceServiceImpl.class, "isCoordRangeValid", 37.0, 127.0)).isTrue();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(PlaceServiceImpl.class, "isCoordRangeValid", 90.0, 180.0)).isTrue();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(PlaceServiceImpl.class, "isCoordRangeValid", null, null)).isTrue();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(PlaceServiceImpl.class, "isCoordRangeValid", 91.0, 127.0)).isFalse();
    }

    @Test
    @DisplayName("지도 마커 저장 시 주소로 중복 제거를 수행해야 한다")
    void saveUserSelectedPlace_pinDedupByAddress() {
        // given
        PlaceUpsertCommand cmd = new PlaceUpsertCommand(
                null, "우리집", "지번", "도로명", null, null, null, null, 126.9, 35.1
        );

        Place existing = Place.builder().id(100L).name("옛날집").build();
        when(placeRepository.findFirstByExternalPlaceIdIsNullAndRoadAddress(cmd.roadAddressName()))
                .thenReturn(Optional.of(existing));

        // when
        Place result = service.saveUserSelectedPlace(cmd);

        // then
        assertThat(result.getId()).isEqualTo(100L);
    }

    @Test
    @DisplayName("카카오 검색 결과 저장 시 externalPlaceId로 중복 제거 및 업데이트를 수행해야 한다")
    void saveUserSelectedPlace_kakaoDedupById() {
        // given
        PlaceUpsertCommand cmd = new PlaceUpsertCommand(
                "12345", "신규스토어", "주소", "도로명", "CE7", "카페", "02-1", "url", 126.9, 35.1
        );

        Place existing = Place.builder().id(200L).externalPlaceId("12345").name("이전스토어").build();
        when(placeRepository.findByExternalPlaceId("12345")).thenReturn(Optional.of(existing));

        // when
        Place result = service.saveUserSelectedPlace(cmd);

        // then
        assertThat(result.getId()).isEqualTo(200L);
        assertThat(existing.getName()).isEqualTo("신규스토어");
    }

    @Test
    @DisplayName("통합 검색 시 신규 장소는 저장하고 기존 장소는 유지하며 결과를 반환해야 한다")
    @SuppressWarnings("unchecked")
    void searchAndStoreAll_savesNewAndReturnsExisting() {
        // given
        PlaceSearchItemResponse item1 = PlaceSearchItemResponse.builder()
                .id("ID1").placeName("기존").longitude(126.9).latitude(35.1).build();
        PlaceSearchItemResponse item2 = PlaceSearchItemResponse.builder()
                .id("ID2").placeName("신규").longitude(126.91).latitude(35.11).build();
        
        when(placeSearchCache.getOrLoadSearch(eq("키워드"), eq(37.0), eq(126.0), any()))
                .thenReturn(List.of(item1, item2));
        
        Place existingPlace = Place.builder().id(10L).externalPlaceId("ID1").name("기존").build();
        when(placeRepository.findAllByExternalPlaceIdIn(List.of("ID1", "ID2")))
                .thenReturn(List.of(existingPlace));
        
        when(placeRepository.save(any(Place.class))).thenReturn(Place.builder().id(11L).externalPlaceId("ID2").build());

        // when
        PlaceService.SearchResult result = service.searchAndStoreAll("키워드", 37.0, 126.0);

        // then
        assertThat(result.searchItems()).hasSize(2);
        assertThat(result.storedPlaces()).hasSize(2);
        verify(placeRepository).save(any(Place.class));
    }

    @Test
    @SuppressWarnings("unchecked")
    @DisplayName("캐시 Loader 실행 시 카카오 호출 지표가 기록되어야 한다")
    void searchAndStoreAll_recordsMetrics() {
        // given
        when(placeSearchCache.getOrLoadSearch(any(), any(), any(), any()))
                .thenAnswer(inv -> ((Supplier<List<PlaceSearchItemResponse>>) inv.getArgument(3)).get());
        when(kakaoLocalClient.searchByKeyword(any(), any(), any())).thenReturn(Mono.just(new KakaoLocalSearchResponse()));

        // when
        service.searchAndStoreAll("약국", 35.1, 126.9);

        // then
        assertThat(registry.counter("place.kakao.search.load").count()).isEqualTo(1.0);
    }
}
