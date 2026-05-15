package com.timingnote.api.domain.recommend.service;

import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;

public interface RecommendService {

    RecommendListResponseDto getRecommendations(Long userId, RecommendListRequestDto requestDto);
}
