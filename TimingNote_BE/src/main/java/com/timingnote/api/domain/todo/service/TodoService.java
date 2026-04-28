package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;

public interface TodoService {
    TodoCreateResponse createTodo(Long userId, TodoCreateRequest request);

    TodoListResponse getTodoList(Long userId, String status, String tab, String placeType, Long cursor, int limit);

    TodoDetailResponse getTodoDetail(Long userId, Long todoId);

    void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude);

    void markStructureFailed(Long todoId);
}
