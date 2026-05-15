package com.timingnote.api.domain.recommend.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.recommend.dto.request.RecommendListRequestDto;
import com.timingnote.api.domain.recommend.dto.response.RecommendListResponseDto;
import com.timingnote.api.domain.recommend.service.RecommendService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * RECO-01 추천 API 컨트롤러.
 */
@Tag(name = "추천", description = "위치 기반 추천 API")
@RestController
@RequestMapping("/api/v1/recommendations")
@RequiredArgsConstructor
public class RecommendController {

    private final RecommendService recommendService;

    @Operation(
            summary = "위치 기반 추천 조회",
            description = "현재 좌표, 반경, 트리거를 기준으로 추천 가능한 할 일 목록을 반환한다."
    )
    @GetMapping
    public ApiResponseDto<RecommendListResponseDto> getRecommendations(
            HttpServletRequest request,
            @Valid @ModelAttribute RecommendListRequestDto requestDto
    ) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(recommendService.getRecommendations(userId, requestDto));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
