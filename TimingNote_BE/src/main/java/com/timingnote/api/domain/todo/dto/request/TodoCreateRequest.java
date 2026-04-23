package com.timingnote.api.domain.todo.dto.request;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class TodoCreateRequest {
    private String content;
    private String inputType;
}
