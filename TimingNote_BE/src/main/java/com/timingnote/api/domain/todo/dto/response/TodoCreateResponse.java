package com.timingnote.api.domain.todo.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class TodoCreateResponse {
    private Long todoId;
    private String status;
    private String structureStatus;
    private LocalDateTime createdAt;
}
