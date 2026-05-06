package com.timingnote.api.infra.client.ai.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * AI 서버 /internal/structure 응답 모델
 * DDL todo_structures 테이블 컬럼 기준으로 정의
 */
@Getter
@NoArgsConstructor
public class AiStructureResponse {
    private Long todoId;
    private String todoText;
    private String placeText;
    private String placeType;
    private String timeHintText;
    private String category;
    private List<AiTimeCondition> timeConditions = Collections.emptyList();
    private String modelUsed;
    private String requestId;
    private Map<String, Object> rawResultJson;
}
