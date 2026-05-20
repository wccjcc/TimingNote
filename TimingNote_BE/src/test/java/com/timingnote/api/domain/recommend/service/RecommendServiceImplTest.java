package com.timingnote.api.domain.recommend.service;

import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;
import com.timingnote.api.domain.recommend.repository.projection.RecommendCandidateProjection;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoRegionCodeResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import reactor.core.publisher.Mono;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecommendServiceImplTest {

    @Mock
    private KakaoGeoClient kakaoGeoClient;

    @Mock
    private TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    @InjectMocks
    private RecommendServiceImpl recommendService;

    @Test
    void getRecommendations_usesDefaultRadius_whenRadiusIsNull() {
        // given: 반경이 null인 요청
        RecommendListRequestDto request = request(35.19157, 126.82432, null);
        when(kakaoGeoClient.coordToRegionCode(anyString(), anyString()))
                .thenReturn(Mono.just(regionResponse("H", "광주광역시", "치평동", "")));
        when(todoCandidatePlaceRepository.findRecommendCandidates(anyLong(), anyDouble(), anyDouble(), anyInt(), anyInt()))
                .thenReturn(List.of());

        // when: 추천 조회 실행
        recommendService.getRecommendations(2L, request);

        // then: 기본 반경 500m로 조회한다
        ArgumentCaptor<Integer> radiusCaptor = ArgumentCaptor.forClass(Integer.class);
        verify(todoCandidatePlaceRepository).findRecommendCandidates(
                anyLong(), anyDouble(), anyDouble(), radiusCaptor.capture(), anyInt()
        );
        assertThat(radiusCaptor.getValue()).isEqualTo(500);
    }

    @Test
    void getRecommendations_capsRadius_whenRadiusExceedsMax() {
        // given: 반경이 최대값을 초과한 요청
        RecommendListRequestDto request = request(35.19157, 126.82432, 99999);
        when(kakaoGeoClient.coordToRegionCode(anyString(), anyString()))
                .thenReturn(Mono.just(regionResponse("H", "광주광역시", "치평동", "")));
        when(todoCandidatePlaceRepository.findRecommendCandidates(anyLong(), anyDouble(), anyDouble(), anyInt(), anyInt()))
                .thenReturn(List.of());

        // when
        recommendService.getRecommendations(2L, request);

        // then: 최대 반경 2000m로 제한한다
        ArgumentCaptor<Integer> radiusCaptor = ArgumentCaptor.forClass(Integer.class);
        verify(todoCandidatePlaceRepository).findRecommendCandidates(
                anyLong(), anyDouble(), anyDouble(), radiusCaptor.capture(), anyInt()
        );
        assertThat(radiusCaptor.getValue()).isEqualTo(2000);
    }

    @Test
    void getRecommendations_groupsByPlace_andSortsByDistance() {
        // given: 같은 placeId 후보 2개 + 다른 장소 후보 1개
        RecommendListRequestDto request = request(35.19157, 126.82432, 800);
        when(kakaoGeoClient.coordToRegionCode(anyString(), anyString()))
                .thenReturn(Mono.just(regionResponse("H", "광주광역시", "치평동", "")));
        when(todoCandidatePlaceRepository.findRecommendCandidates(anyLong(), anyDouble(), anyDouble(), anyInt(), anyInt()))
                .thenReturn(List.of(
                        candidate(101L, "A-할일", "ACQUIRE", "GENERIC", "이마트", 10L, "이마트", 35.1909, 126.8251, 120),
                        candidate(102L, "B-할일", "SOCIAL", "GENERIC", "이마트", 10L, "이마트", 35.1909, 126.8251, 120),
                        candidate(201L, "C-할일", "HEALTH", "GENERIC", "병원", 20L, "장덕튼튼의원", 35.1921, 126.8238, 80)
                ));

        // when
        RecommendListResponseDto result = recommendService.getRecommendations(2L, request);

        // then: 장소 그룹 2개 + 거리순 정렬 + todoCount 집계
        assertThat(result.getItems()).hasSize(2);

        RecommendListResponseDto.RecommendGroupResponseDto first = result.getItems().get(0);
        RecommendListResponseDto.RecommendGroupResponseDto second = result.getItems().get(1);

        assertThat(first.getRank()).isEqualTo(1);
        assertThat(first.getPlaceName()).isEqualTo("장덕튼튼의원");
        assertThat(first.getDistanceM()).isEqualTo(80);
        assertThat(first.getTodoCount()).isEqualTo(1);

        assertThat(second.getRank()).isEqualTo(2);
        assertThat(second.getPlaceName()).isEqualTo("이마트");
        assertThat(second.getDistanceM()).isEqualTo(120);
        assertThat(second.getTodoCount()).isEqualTo(2);
        assertThat(second.getTodos()).extracting(RecommendListResponseDto.RecommendTodoResponseDto::getTodoId)
                .containsExactly(101L, 102L);
    }

    @Test
    void getRecommendations_prefersAdministrativeDongLabel() {
        // given: B(법정동) 문서와 H(행정동) 문서가 함께 온 응답
        RecommendListRequestDto request = request(35.19157, 126.82432, 300);
        KakaoRegionCodeResponse response = new KakaoRegionCodeResponse();
        ReflectionTestUtils.setField(response, "documents", List.of(
                regionDocument("B", "광주광역시", "수완동", ""),
                regionDocument("H", "광주광역시", "치평동", "")
        ));
        when(kakaoGeoClient.coordToRegionCode(anyString(), anyString()))
                .thenReturn(Mono.just(response));
        when(todoCandidatePlaceRepository.findRecommendCandidates(anyLong(), anyDouble(), anyDouble(), anyInt(), anyInt()))
                .thenReturn(List.of());

        // when
        RecommendListResponseDto result = recommendService.getRecommendations(2L, request);

        // then: H(행정동)인 치평동 라벨을 우선 사용한다
        assertThat(result.getCurrentLocationLabel()).isEqualTo("광주광역시 치평동");
    }

    private RecommendListRequestDto request(double latitude, double longitude, Integer radiusM) {
        RecommendListRequestDto request = new RecommendListRequestDto();
        request.setLatitude(latitude);
        request.setLongitude(longitude);
        request.setRadiusM(radiusM);
        request.setTriggerType("HOME_ENTER");
        request.setCourse(0.0);
        return request;
    }

    private KakaoRegionCodeResponse regionResponse(String regionType, String depth1, String depth3, String depth4) {
        KakaoRegionCodeResponse response = new KakaoRegionCodeResponse();
        ReflectionTestUtils.setField(response, "documents", List.of(regionDocument(regionType, depth1, depth3, depth4)));
        return response;
    }

    private KakaoRegionCodeResponse.Document regionDocument(String regionType, String depth1, String depth3, String depth4) {
        KakaoRegionCodeResponse.Document doc = new KakaoRegionCodeResponse.Document();
        ReflectionTestUtils.setField(doc, "regionType", regionType);
        ReflectionTestUtils.setField(doc, "region1DepthName", depth1);
        ReflectionTestUtils.setField(doc, "region3DepthName", depth3);
        ReflectionTestUtils.setField(doc, "region4DepthName", depth4);
        ReflectionTestUtils.setField(doc, "addressName", depth1 + " " + depth3);
        return doc;
    }

    private RecommendCandidateProjection candidate(
            Long todoId,
            String summaryText,
            String category,
            String todoType,
            String resolvedPlaceLabel,
            Long placeId,
            String placeName,
            Double latitude,
            Double longitude,
            Integer distanceM
    ) {
        return new RecommendCandidateProjection() {
            @Override
            public Long getTodoId() {
                return todoId;
            }

            @Override
            public String getSummaryText() {
                return summaryText;
            }

            @Override
            public String getCategory() {
                return category;
            }

            @Override
            public String getTodoType() {
                return todoType;
            }

            @Override
            public String getResolvedPlaceLabel() {
                return resolvedPlaceLabel;
            }

            @Override
            public Long getPlaceId() {
                return placeId;
            }

            @Override
            public String getPlaceName() {
                return placeName;
            }

            @Override
            public Double getLatitude() {
                return latitude;
            }

            @Override
            public Double getLongitude() {
                return longitude;
            }

            @Override
            public Integer getDistanceM() {
                return distanceM;
            }
        };
    }
}
