package com.timingnote.api.domain.todo.search.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TodoReindexRequest {

    /** null이면 전체 사용자, 아니면 해당 사용자 todo만 재색인. */
    private Long userId;

    /** 이 ID보다 큰 todo부터 재색인. null이면 처음부터. */
    private Long fromId;

    /** 한 배치당 가져올 todo 수. 기본 500, 최대 5000. */
    @Min(1)
    @Max(5000)
    private Integer batchSize;
}
