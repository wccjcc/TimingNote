package com.timingnote.api.domain.recommend.service;

import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 추천 서비스 구현체.
 * 비즈니스 로직은 팀 협의 후 단계적으로 구현한다.
 */
@Service
@RequiredArgsConstructor
public class RecommendServiceImpl implements RecommendService {

    @Override
    public RecommendListResponseDto getRecommendations(Long userId, RecommendListRequestDto requestDto) {
        // TODO: Business logic must be implemented by the user.
        // 1) 현재 좌표 기반 위치 라벨 생성(currentLocationLabel)
        // 2) 추천 대상 Todo 조회 및 필터링
        // 3) 거리/점수 계산 및 정렬
        // 4) RECO-01 응답 DTO 매핑
        throw new UnsupportedOperationException("TODO: implement recommendation business logic");
    }
}
