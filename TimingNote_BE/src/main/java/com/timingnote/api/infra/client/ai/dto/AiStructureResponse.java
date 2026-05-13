package com.timingnote.api.infra.client.ai.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * AI 서버 /internal/structure 응답 모델.
 *
 * <p>2026-05-12 설계 변경: placeType은 BE가 검색 결과·user_places 매칭으로 자체 결정한다
 * (문서 4-2). AI 응답에서 제거됨 — Jackson은 unknown property를 기본 무시하므로 안전.
 */
@Getter
@NoArgsConstructor
public class AiStructureResponse {
    private Long todoId;
    private String todoText;
    private String placeText;
    private String timeHintText;
    private String category;
    private List<AiTimeCondition> timeConditions = Collections.emptyList();
    private String modelUsed;
    private String requestId;
    private Map<String, Object> rawResultJson;
}
