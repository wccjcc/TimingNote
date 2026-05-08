package com.timingnote.api.domain.todo.search.dto;

import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;
import org.springframework.data.elasticsearch.core.SearchHit;

import java.util.List;
import java.util.Map;

@Getter
@Builder
@Schema(description = "할 일 검색 결과 항목")
public class TodoSearchItemResponse {

    @Schema(description = "할 일 ID — 클릭 시 상세 페이지 이동에 사용")
    private Long id;

    @Schema(description = "원문 내용")
    private String content;

    @Schema(description = "필드별 하이라이팅 (검색어 위치를 <em></em>로 감싼 fragment)")
    private Map<String, List<String>> highlights;

    @Schema(description = "할 일 유형 (SPECIFIC | GENERIC | ALIAS | GENERAL) — 아이콘 분기용")
    private String todoType;

    @Schema(description = "진행 상태 (ACTIVE | DONE) — 체크 표시용")
    private String status;

    @Schema(description = "카테고리 (DINE | ACQUIRE | HEALTH | SERVICE) — 카테고리 칩용")
    private String category;

    @Schema(description = "장소 표시 레이블 (예: '강남역 약국')")
    private String resolvedPlaceLabel;

    public static TodoSearchItemResponse from(SearchHit<TodoSearchDocument> hit) {
        TodoSearchDocument doc = hit.getContent();
        Long id = doc.getId() != null ? Long.parseLong(doc.getId()) : null;

        return TodoSearchItemResponse.builder()
                .id(id)
                .content(doc.getContent())
                .highlights(hit.getHighlightFields())
                .todoType(doc.getTodoType())
                .status(doc.getStatus())
                .category(doc.getCategory())
                .resolvedPlaceLabel(doc.getPlaceLabel())
                .build();
    }
}
