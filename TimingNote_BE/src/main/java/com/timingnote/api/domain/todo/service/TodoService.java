package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;

public interface TodoService {
    TodoCreateResponse createTodo(Long userId, TodoCreateRequest request);

    void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude);

    void markStructureFailed(Long todoId);
}
