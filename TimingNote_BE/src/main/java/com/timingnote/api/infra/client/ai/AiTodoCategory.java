package com.timingnote.api.infra.client.ai;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum AiTodoCategory {
    DINE("식사/카페"),
    ACQUIRE("쇼핑/수령"),
    HEALTH("병원/약국/운동"),
    SERVICE("은행/관공서/업무"),
    MAINTENANCE("세탁/주유/정비"),
    SOCIAL("모임/방문/선물"),
    ETC("기타 메모");

    private final String label;
}
