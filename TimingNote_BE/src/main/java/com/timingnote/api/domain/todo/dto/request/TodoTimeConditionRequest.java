package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
@Schema(description = "시간 조건 입력")
public class TodoTimeConditionRequest {

    @NotBlank
    @Schema(description = "조건 유형", allowableValues = {"DATETIME", "DATE", "DATE_RANGE", "WEEK", "TIME_RANGE"})
    private String conditionType;

    @Schema(description = "시작 날짜 (yyyy-MM-dd)")
    private String startDate;

    @Schema(description = "종료 날짜 (yyyy-MM-dd)")
    private String endDate;

    @Schema(description = "시작 시각 (HH:mm:ss)")
    private String startTime;

    @Schema(description = "종료 시각 (HH:mm:ss)")
    private String endTime;

    @Schema(description = "요일 목록 (MON, TUE, WED, THU, FRI, SAT, SUN)")
    private List<String> daysOfWeek;

    @Schema(description = "원문 시간 표현")
    private String rawExpression;
}
