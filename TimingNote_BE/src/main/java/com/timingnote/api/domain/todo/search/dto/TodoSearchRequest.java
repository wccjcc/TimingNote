package com.timingnote.api.domain.todo.search.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoSearchRequest {

    /** 검색어. 빈 문자열 시 400. */
    @NotBlank
    private String q;

    /** 옵션: ACTIVE | DONE. 미지정 시 ACTIVE. */
    private String status;

    /** 옵션: DINE | ACQUIRE | HEALTH | SERVICE. */
    private String category;

    /** 옵션: SPECIFIC | GENERIC | ALIAS | GENERAL. */
    private String todoType;

    /** 페이지네이션 커서(불투명 토큰). 첫 페이지에는 null. */
    private String cursor;

    /** 한 페이지 크기. 기본 20, 1~50. */
    @Min(1)
    @Max(50)
    private Integer size;
}
