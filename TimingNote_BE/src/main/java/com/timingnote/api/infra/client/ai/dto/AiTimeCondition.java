package com.timingnote.api.infra.client.ai.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class AiTimeCondition {
    private String conditionType;        // DATETIME | DATE | DATE_RANGE | WEEKDAY | TIME_RANGE
    private List<String> daysOfWeek;     // ["MON","TUE",...] → BE에서 비트마스크로 변환
    private String startDate;            // yyyy-MM-dd
    private String endDate;              // yyyy-MM-dd
    private String startTime;            // HH:mm
    private String endTime;              // HH:mm
    private String rawExpression;        // 원문 시간 표현
}
