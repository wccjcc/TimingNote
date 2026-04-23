package com.timingnote.api.domain.todo.controller;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.service.TodoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/todos")
@RequiredArgsConstructor
public class TodoController {

    private final TodoService todoService;

    @PostMapping
    public ResponseEntity<TodoCreateResponse> createTodo(@RequestBody TodoCreateRequest request) {
        // TODO: SecurityContextHolder 등을 통해 실제 로그인 유저 ID를 가져와야 함
        Long tempUserId = 1L;
        TodoCreateResponse response = todoService.createTodo(tempUserId, request);
        return ResponseEntity.ok(response);
    }
}
