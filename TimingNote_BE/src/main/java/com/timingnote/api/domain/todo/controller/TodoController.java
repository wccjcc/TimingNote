package com.timingnote.api.domain.todo.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.domain.todo.service.TodoService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "할 일", description = "Todo API")
@RestController
@RequestMapping("/api/v1/todos")
@RequiredArgsConstructor
public class TodoController {

    private final TodoService todoService;

    @Operation(
            summary = "Todo 생성",
            description = "자연어 메모를 Todo로 저장한다. 저장 즉시 응답하며, AI 구조화는 비동기로 처리된다."
    )
    @ApiResponse(responseCode = "200", description = "생성 성공")
    @ApiResponse(responseCode = "400", description = "입력값 오류 (content 누락, inputType 범위 초과 등)",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PostMapping
    public ApiResponseDto<TodoCreateResponse> createTodo(
            HttpServletRequest request,
            @Valid @RequestBody TodoCreateRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.createTodo(userId, body));
    }

    @Operation(
            summary = "할 일 목록 조회",
            description = "커서 기반 페이징. tab 미입력 시 전체, status 미입력 시 DELETED 제외 전체 반환."
    )
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @GetMapping
    public ApiResponseDto<TodoListResponse> getTodoList(
            HttpServletRequest request,
            @Parameter(description = "상태 필터 (ACTIVE | DONE, 미입력 시 DELETED 제외 전체)")
            @RequestParam(required = false) String status,
            @Parameter(description = "카테고리 탭 (DINE | ACQUIRE | HEALTH | SERVICE, 미입력 시 전체)")
            @RequestParam(required = false) String tab,
            @Parameter(description = "장소 유형 필터 (SPECIFIC | GENERIC | ALIAS | GENERAL, 미입력 시 전체)")
            @RequestParam(required = false) String placeType,
            @Parameter(description = "커서 (이전 응답의 nextCursor, 첫 요청 시 미입력)")
            @RequestParam(required = false) Long cursor,
            @Parameter(description = "페이지 크기 (기본 20, 최대 50)")
            @RequestParam(defaultValue = "20") int limit) {
        Long userId = extractAuthenticatedUserId(request);
        int safeLimit = Math.min(limit, 50);
        return ApiResponseDto.success(todoService.getTodoList(userId, status, tab, placeType, cursor, safeLimit));
    }

    @Operation(
            summary = "할 일 상세 조회",
            description = "Todo 단건의 상세 정보(구조화 결과, 시간 조건, 장소 등)를 반환한다."
    )
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @GetMapping("/{todoId}")
    public ApiResponseDto<TodoDetailResponse> getTodoDetail(
            HttpServletRequest request,
            @PathVariable Long todoId) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.getTodoDetail(userId, todoId));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
