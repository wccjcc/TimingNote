package com.timingnote.api.domain.todo.dto.response;

import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@Builder
@Schema(description = "시간 조건")
public class TodoTimeConditionResponse {

    @Schema(description = "조건 유형", allowableValues = {"DATETIME", "DATE", "DATE_RANGE", "WEEKDAY", "TIME_RANGE"})
    private String conditionType;

    @Schema(description = "시작 날짜")
    private LocalDate startDate;

    @Schema(description = "종료 날짜")
    private LocalDate endDate;

    @Schema(description = "시작 시각")
    private LocalTime startTime;

    @Schema(description = "종료 시각")
    private LocalTime endTime;

    @Schema(description = "요일 비트마스크 (MON=1,TUE=2,WED=4,THU=8,FRI=16,SAT=32,SUN=64)")
    private Short daysOfWeek;

    @Schema(description = "원문 시간 표현")
    private String rawExpression;

    public static TodoTimeConditionResponse from(TodoTimeCondition tc) {
        return TodoTimeConditionResponse.builder()
                .conditionType(tc.getConditionType())
                .startDate(tc.getStartDate())
                .endDate(tc.getEndDate())
                .startTime(tc.getStartTime())
                .endTime(tc.getEndTime())
                .daysOfWeek(tc.getDaysOfWeek())
                .rawExpression(tc.getRawExpression())
                .build();
    }
}
