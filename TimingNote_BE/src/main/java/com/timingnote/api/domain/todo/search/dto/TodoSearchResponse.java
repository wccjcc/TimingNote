package com.timingnote.api.domain.todo.search.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "할 일 검색 응답")
public class TodoSearchResponse {

    @Schema(description = "검색 결과 목록")
    private List<TodoSearchItemResponse> items;

    @Schema(description = "다음 페이지 커서. 더 이상 결과 없으면 null")
    private String nextCursor;

    @Schema(description = "총 매칭 수 (track_total_hits 한도 내)")
    private long total;

    public static TodoSearchResponse empty() {
        return TodoSearchResponse.builder()
                .items(List.of())
                .nextCursor(null)
                .total(0)
                .build();
    }
}
