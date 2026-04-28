package com.timingnote.api.domain.todo.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
@Schema(description = "할 일 목록 (커서 페이징)")
public class TodoListResponse {

    @Schema(description = "할 일 목록")
    private List<TodoListItemResponse> items;

    @Schema(description = "다음 페이지 커서 (null 이면 마지막 페이지)")
    private Long nextCursor;
}
