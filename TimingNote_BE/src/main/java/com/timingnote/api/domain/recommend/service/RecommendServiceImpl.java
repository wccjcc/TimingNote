package com.timingnote.api.domain.recommend.service;

import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;
import com.timingnote.api.domain.recommend.repository.projection.RecommendCandidateProjection;
import com.timingnote.api.infra.client.kakao.KakaoGeoClient;
import com.timingnote.api.infra.client.kakao.dto.KakaoRegionCodeResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RecommendServiceImpl implements RecommendService {

    private static final int DEFAULT_RADIUS_M = 500;
    private static final int MAX_RADIUS_M = 2000;
    private static final int MAX_CANDIDATE_SIZE = 100;

    private final KakaoGeoClient kakaoGeoClient;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;

    /*
    추천 할일들을 받아 RecommendListResponseDto로 반환하는 메서드
     */
    @Override
    public RecommendListResponseDto getRecommendations(Long userId, RecommendListRequestDto requestDto) {

        //현재 위치 행정동으로 변환
        String currentLocationLabel = resolveCurrentLocationLabel(
                requestDto.getLatitude(),
                requestDto.getLongitude()
        );

        //요청 반경 유효화(기본값/상한 적용)
        int radiusM = normalizeRadius(requestDto.getRadiusM());
        //후보지 선정
        // - userId의 Active todo만
        // - 반경 내의 후보만
        // - GENERIC(todo_type)은 todo당 최대 2개
        // - 거리 오름차순
        List<RecommendCandidateProjection> candidates = todoCandidatePlaceRepository.findRecommendCandidates(
                userId,
                requestDto.getLatitude(),
                requestDto.getLongitude(),
                radiusM,
                MAX_CANDIDATE_SIZE
        );

        // 같은 장소(placeId)끼리 묶어서 그룹 응답으로 변환
        List<RecommendListResponseDto.RecommendGroupResponseDto> items = mapToGroups(candidates);

        // 최종 응답 조립
        return RecommendListResponseDto.builder()
                .currentLocationLabel(currentLocationLabel)
                .items(items)
                .build();
    }

    //radius 형식에 맞추기
    private int normalizeRadius(Integer radiusM) {
        if (radiusM == null || radiusM < 1) {
            return DEFAULT_RADIUS_M;
        }
        return Math.min(radiusM, MAX_RADIUS_M);
    }

    //group으로 만들기
    private List<RecommendListResponseDto.RecommendGroupResponseDto> mapToGroups(
            List<RecommendCandidateProjection> candidates
    ) {
        //후보지가 없을 경우 빈 리스트 반환
        if (candidates == null || candidates.isEmpty()) {
            return List.of();
        }


        //placeId 기준 그룹화
        //LinkedHashMap 사용 : 입력 순서를 최대한 유지하기 위해
        Map<Long, List<RecommendCandidateProjection>> byPlace = candidates.stream()
                .collect(Collectors.groupingBy(
                        RecommendCandidateProjection::getPlaceId,
                        LinkedHashMap::new,
                        Collectors.toList()
                ));

        List<RecommendListResponseDto.RecommendGroupResponseDto> groups = new ArrayList<>();

        // 장소 그룹별로 응답 모델 생성
        for (Map.Entry<Long, List<RecommendCandidateProjection>> entry : byPlace.entrySet()) {
            List<RecommendCandidateProjection> placeCandidates = entry.getValue();
            if (placeCandidates.isEmpty()) {
                continue;
            }

            // 그룹 대표 후보(head) : 같은 장소 내에서 가장 가까운 후보 1개
            RecommendCandidateProjection head = placeCandidates.stream()
                    .min(Comparator.comparingInt(c -> safeDistance(c.getDistanceM())))
                    .orElse(placeCandidates.get(0));

            // 같은 장소에 걸린 할일 목록 변환 (todo[])
            List<RecommendListResponseDto.RecommendTodoResponseDto> todos = placeCandidates.stream()
                    .map(candidate -> RecommendListResponseDto.RecommendTodoResponseDto.builder()
                            .todoId(candidate.getTodoId())
                            .summaryText(candidate.getSummaryText())
                            .category(candidate.getCategory())
                            .resolvedPlaceLabel(candidate.getResolvedPlaceLabel())
                            .build())
                    .toList();

            //rank는 일단 0으로 넣고, 아래 정렬 후 다시 1..N 재부여
            groups.add(RecommendListResponseDto.RecommendGroupResponseDto.builder()
                    .rank(0)
                    .groupId(head.getPlaceId()) //현재는 placeId를 groupId로 사용
                    .placeName(head.getPlaceName())
                    .latitude(head.getLatitude())
                    .longitude(head.getLongitude())
                    .distanceM(head.getDistanceM()) //그룹 대표 거리 = 가장 가까운 후보 거리
                    .todoCount(todos.size()) //프론트 배지 숫자로 사용
                    .todos(todos)
                    .build());
        }

        //그룹 자체도 거리순 정렬
        groups.sort(Comparator.comparingInt(g -> safeDistance(g.getDistanceM())));

        //정렬 결과 기준으로 rank 1..N 다시 부여
        for (int i = 0; i < groups.size(); i++) {
            RecommendListResponseDto.RecommendGroupResponseDto g = groups.get(i);
            groups.set(i, RecommendListResponseDto.RecommendGroupResponseDto.builder()
                    .rank(i + 1)
                    .groupId(g.getGroupId())
                    .placeName(g.getPlaceName())
                    .latitude(g.getLatitude())
                    .longitude(g.getLongitude())
                    .distanceM(g.getDistanceM())
                    .todoCount(g.getTodoCount())
                    .todos(g.getTodos())
                    .build());
        }

        return groups;
    }

    // null 거리 방어 : 정렬 시 맨 뒤로 보내기 위해 매우 큰 값 사용
    private int safeDistance(Integer distanceM) {
        return distanceM == null ? Integer.MAX_VALUE : distanceM;
    }

    //카카오 coord2regioncode 호출
    //주의 : AI는 x = 경도, y = 위도 순서
    private String resolveCurrentLocationLabel(double latitude, double longitude) {
        KakaoRegionCodeResponse response = kakaoGeoClient
                .coordToRegionCode(String.valueOf(longitude), String.valueOf(latitude))
                .block();

        //응답이 비어있으면 라벨을 만들 수 없으니 null
        if (response == null || response.getDocuments() == null || response.getDocuments().isEmpty()) {
            return null;
        }

        // 행정동(H) 우선 선택, 없으면 첫 문서 fallback
        KakaoRegionCodeResponse.Document target = response.getDocuments().stream()
                .filter(doc -> "H".equalsIgnoreCase(doc.getRegionType()))
                .findFirst()
                .orElse(response.getDocuments().get(0));

        // depth1: 시/도, depth3: 동/읍/면, depth4: 리
        String depth1 = safe(target.getRegion1DepthName());
        String depth3 = safe(target.getRegion3DepthName());
        String depth4 = safe(target.getRegion4DepthName());

        if (!depth1.isEmpty() && !depth3.isEmpty()) {
            return depth1 + " " + depth3;
        }
        if (!depth1.isEmpty() && !depth4.isEmpty()) {
            return depth1 + " " + depth4;
        }
        if (!depth1.isEmpty()) {
            return depth1;
        }

        String addressName = safe(target.getAddressName());
        return addressName.isEmpty() ? null : addressName;
    }

    // null-safe trim 유틸
    private String safe(String value) {
        return value == null ? "" : value.trim();
    }
}
