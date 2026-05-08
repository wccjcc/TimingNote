package com.timingnote.api.domain.todo.search.service;

import com.timingnote.api.domain.todo.search.dto.TodoSearchRequest;
import com.timingnote.api.domain.todo.search.dto.TodoSearchResponse;

public interface TodoSearchService {
    TodoSearchResponse search(Long userId, TodoSearchRequest request);
}
