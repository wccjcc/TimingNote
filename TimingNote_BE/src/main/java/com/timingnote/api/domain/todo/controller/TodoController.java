package com.timingnote.api.domain.todo.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.todo.dto.request.TodoAliasPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoAlertUpdateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoStatusUpdateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoUpdateRequest;
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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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

    @Operation(
            summary = "할 일 수정",
            description = "변경할 필드만 포함. null = 유지, 빈 문자열(\"\") = 제거, 빈 배열([]) = 전체 삭제."
    )
    @ApiResponse(responseCode = "200", description = "수정 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PatchMapping("/{todoId}")
    public ApiResponseDto<TodoDetailResponse> updateTodo(
            HttpServletRequest request,
            @PathVariable Long todoId,
            @Valid @RequestBody TodoUpdateRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.updateTodo(userId, todoId, body));
    }

    @Operation(summary = "알림 설정 변경", description = "알림 on/off 토글. 목록/상세 페이지에서 사용.")
    @ApiResponse(responseCode = "200", description = "변경 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PatchMapping("/{todoId}/alert")
    public ApiResponseDto<Void> updateAlert(
            HttpServletRequest request,
            @PathVariable Long todoId,
            @Valid @RequestBody TodoAlertUpdateRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        todoService.updateAlert(userId, todoId, body.getAlertEnabled());
        return ApiResponseDto.success(null);
    }

    @Operation(summary = "완료 상태 변경", description = "ACTIVE ↔ DONE 토글. 목록/상세 페이지에서 사용.")
    @ApiResponse(responseCode = "200", description = "변경 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PatchMapping("/{todoId}/status")
    public ApiResponseDto<Void> updateStatus(
            HttpServletRequest request,
            @PathVariable Long todoId,
            @Valid @RequestBody TodoStatusUpdateRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        todoService.updateStatus(userId, todoId, body.getStatus());
        return ApiResponseDto.success(null);
    }

    @Operation(
            summary = "할 일 삭제",
            description = "소프트 삭제 — status를 DELETED로 변경한다. 목록 조회에서 자동으로 제외된다."
    )
    @ApiResponse(responseCode = "200", description = "삭제 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @DeleteMapping("/{todoId}")
    public ApiResponseDto<Void> deleteTodo(
            HttpServletRequest request,
            @PathVariable Long todoId) {
        Long userId = extractAuthenticatedUserId(request);
        todoService.deleteTodo(userId, todoId);
        return ApiResponseDto.success(null);
    }

    @Operation(
            summary = "Todo 장소 지정",
            description = "FE에서 Kakao 검색으로 선택한 장소를 Todo에 연결한다. places 테이블에 upsert 후 primaryPlaceId를 갱신한다."
    )
    @ApiResponse(responseCode = "200", description = "지정 성공")
    @ApiResponse(responseCode = "400", description = "필수 필드 누락 (kakaoPlaceId, placeName, longitude, latitude)",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PostMapping("/{todoId}/place")
    public ApiResponseDto<TodoDetailResponse> setTodoPlace(
            HttpServletRequest request,
            @PathVariable Long todoId,
            @Valid @RequestBody TodoPlaceSetRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.setTodoPlace(userId, todoId, body));
    }

    @Operation(
            summary = "내 장소(별칭)로 Todo 장소 지정",
            description = "사전 등록한 내 장소(UserPlace)를 Todo에 연결한다. todoType = ALIAS, resolvedPlaceLabel = 별칭명으로 설정된다."
    )
    @ApiResponse(responseCode = "200", description = "지정 성공")
    @ApiResponse(responseCode = "400", description = "필수 필드 누락 (userPlaceId)",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo 또는 내 장소",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @PostMapping("/{todoId}/place/alias")
    public ApiResponseDto<TodoDetailResponse> setTodoPlaceFromAlias(
            HttpServletRequest request,
            @PathVariable Long todoId,
            @Valid @RequestBody TodoAliasPlaceSetRequest body) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.setTodoPlaceFromAlias(userId, todoId, body));
    }

    @Operation(
            summary = "Todo 장소 연결 해제",
            description = "Todo에 연결된 장소(primaryPlaceId)를 제거한다."
    )
    @ApiResponse(responseCode = "200", description = "해제 성공")
    @ApiResponse(responseCode = "401", description = "유효하지 않은 Device Secret",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "403", description = "다른 사용자의 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @ApiResponse(responseCode = "404", description = "존재하지 않는 Todo",
            content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    @DeleteMapping("/{todoId}/place")
    public ApiResponseDto<TodoDetailResponse> removeTodoPlace(
            HttpServletRequest request,
            @PathVariable Long todoId) {
        Long userId = extractAuthenticatedUserId(request);
        return ApiResponseDto.success(todoService.removeTodoPlace(userId, todoId));
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userIdAttr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (!(userIdAttr instanceof Long userId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return userId;
    }
}
