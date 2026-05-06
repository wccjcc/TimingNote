package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoAliasPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoUpdateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;

public interface TodoService {
    TodoCreateResponse createTodo(Long userId, TodoCreateRequest request);

    TodoListResponse getTodoList(Long userId, String status, String tab, String placeType, Long cursor, int limit);

    TodoDetailResponse getTodoDetail(Long userId, Long todoId);

    TodoDetailResponse updateTodo(Long userId, Long todoId, TodoUpdateRequest request);

    void updateAlert(Long userId, Long todoId, boolean alertEnabled);

    void updateStatus(Long userId, Long todoId, String status);

    /**
     * FE에서 Kakao 검색으로 선택한 장소를 Todo에 연결한다.
     * places 테이블에 upsert 후 todoType=SPECIFIC, todo_candidate_places 단건 등록.
     */
    TodoDetailResponse setTodoPlace(Long userId, Long todoId, TodoPlaceSetRequest request);

    /**
     * 내 장소(UserPlace)에서 선택한 별칭 장소를 Todo에 연결한다.
     * todoType=ALIAS, resolvedPlaceLabel=aliasName, todo_candidate_places 단건 등록.
     */
    TodoDetailResponse setTodoPlaceFromAlias(Long userId, Long todoId, TodoAliasPlaceSetRequest request);

    /**
     * Todo에 연결된 장소를 해제한다 (primaryPlaceId → null, resolvedPlaceLabel → null).
     * PATCH placeText: "" 와 동일한 결과이나, 명시적 해제용으로 별도 제공.
     */
    TodoDetailResponse removeTodoPlace(Long userId, Long todoId);

    /** 소프트 삭제 — status = DELETED, deletedAt = now() */
    void deleteTodo(Long userId, Long todoId);

    void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude);

    void markStructureFailed(Long todoId);
}
