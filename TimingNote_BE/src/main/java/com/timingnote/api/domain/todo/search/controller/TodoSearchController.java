package com.timingnote.api.domain.todo.search.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.todo.search.dto.TodoSearchRequest;
import com.timingnote.api.domain.todo.search.dto.TodoSearchResponse;
import com.timingnote.api.domain.todo.search.service.TodoSearchService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "할 일 검색", description = "Todo Search API")
@Validated
@RestController
@RequestMapping("/api/v1/todos/search")
@RequiredArgsConstructor
public class TodoSearchController {

    private final TodoSearchService todoSearchService;

    @Operation(
            summary = "할 일 본문 검색",
            description = "사용자 본인의 todo 중 q와 매칭되는 항목을 score 순으로 반환한다. " +
                    "한국어 형태소 분석(Nori) + 필드별 가중치(content^4, placeLabel^2, placeName^1) 적용."
    )
    @GetMapping
    public ApiResponseDto<TodoSearchResponse> search(
            HttpServletRequest request,
            @Parameter(description = "검색어 (필수, 빈 문자열 불가)")
            @RequestParam @NotBlank String q,
            @Parameter(description = "상태 필터 (ACTIVE | DONE). 미입력 시 ACTIVE만. 완료 항목 검색 시 DONE 명시.")
            @RequestParam(required = false) String status,
            @Parameter(description = "카테고리 (DINE | ACQUIRE | HEALTH | SERVICE)")
            @RequestParam(required = false) String category,
            @Parameter(description = "장소 유형 (SPECIFIC | GENERIC | ALIAS | GENERAL)")
            @RequestParam(required = false) String todoType,
            @Parameter(description = "다음 페이지 커서 (이전 응답의 nextCursor)")
            @RequestParam(required = false) String cursor,
            @Parameter(description = "페이지 크기 (1~50, 기본 20)")
            @RequestParam(required = false) Integer size
    ) {
        Long userId = extractAuthenticatedUserId(request);

        TodoSearchRequest req = TodoSearchRequest.builder()
                .q(q)
                .status(status)
                .category(category)
                .todoType(todoType)
                .cursor(cursor)
                .size(size)
                .build();

        return ApiResponseDto.success(todoSearchService.search(userId, req));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
