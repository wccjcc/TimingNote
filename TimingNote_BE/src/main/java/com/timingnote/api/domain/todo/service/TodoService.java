package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoUpdateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;

import java.util.List;

public interface TodoService {
    TodoCreateResponse createTodo(Long userId, TodoCreateRequest request);

    TodoListResponse getTodoList(Long userId, String status, String tab, String placeType, Long cursor, int limit);

    TodoDetailResponse getTodoDetail(Long userId, Long todoId);

    TodoDetailResponse updateTodo(Long userId, Long todoId, TodoUpdateRequest request);

    void updateAlert(Long userId, Long todoId, boolean alertEnabled);

    void updateStatus(Long userId, Long todoId, String status);

    /**
     * Todo에 장소를 지정한다.
     * - userPlaceId 있음  → todoType=ALIAS  (내 장소 목록에서 선택)
     * - externalPlace 있음 → todoType=SPECIFIC (Kakao 키워드/주소 검색, 지도 마커 핀)
     * 둘 다 있거나 둘 다 없으면 VALIDATION_ERROR.
     */
    TodoDetailResponse setTodoPlace(Long userId, Long todoId, TodoPlaceSetRequest request);

    /**
     * Todo에 연결된 장소를 해제한다 (primaryPlaceId → null, resolvedPlaceLabel → null).
     * PATCH placeText: "" 와 동일한 결과이나, 명시적 해제용으로 별도 제공.
     */
    TodoDetailResponse removeTodoPlace(Long userId, Long todoId);

    /**
     * 단건/다중 소프트 삭제 — status = DELETED, deletedAt = now().
     * 전달된 ID 중 하나라도 소유권이 없으면 전체 실패(FORBIDDEN).
     */
    void deleteTodos(Long userId, List<Long> ids);

    void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude);

    void markStructureFailed(Long todoId);
}
