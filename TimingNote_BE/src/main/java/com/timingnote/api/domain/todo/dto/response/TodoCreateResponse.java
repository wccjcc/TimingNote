package com.timingnote.api.domain.todo.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;

@Getter
@Builder
@AllArgsConstructor
@Schema(description = "Todo 생성 응답")
public class TodoCreateResponse {

    @Schema(description = "생성된 Todo ID", example = "1")
    private Long todoId;

    @Schema(description = "Todo 상태", allowableValues = {"ACTIVE", "DELETED", "DONE"}, example = "ACTIVE")
    private String status;

    @Schema(description = "AI 구조화 상태 (비동기 처리)", allowableValues = {"PENDING", "READY", "FAILED"}, example = "PENDING")
    private String structureStatus;

    @Schema(description = "생성 시각 (UTC+9)", example = "2026-04-23T15:30:00+09:00")
    private OffsetDateTime createdAt;
}
