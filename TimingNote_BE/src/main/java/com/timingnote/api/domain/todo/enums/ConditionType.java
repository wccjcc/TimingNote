package com.timingnote.api.domain.todo.enums;

public enum ConditionType {
    DATETIME, //정확한 일시
    DATE, //정확한 날짜
    DATE_RANGE, //날짜 범위
    WEEK, //매주 반복
    TIME_RANGE //시간 범위
}
