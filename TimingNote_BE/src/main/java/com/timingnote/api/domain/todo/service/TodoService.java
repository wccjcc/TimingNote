package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
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

    void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude);

    void markStructureFailed(Long todoId);
}
