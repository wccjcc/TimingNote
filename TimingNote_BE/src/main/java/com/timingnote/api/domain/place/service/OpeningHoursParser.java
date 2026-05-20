package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.entity.PlaceOpeningPeriod;
import com.timingnote.api.infra.client.google.dto.GoogleOpeningHours;
import com.timingnote.api.infra.client.google.dto.GoogleOpeningHours.Period;
import com.timingnote.api.infra.client.google.dto.GoogleOpeningHours.TimePoint;

import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;

/**
 * Google Places regularOpeningHours → PlaceOpeningPeriod 변환
 *
 * Google 응답 케이스:
 *   1. 일반: open/close 동일 day — 예) 월 10:00~22:00
 *   2. 자정 넘김: open.day != close.day — 예) 금 22:00 → 토 03:00
 *   3. 24/7: periods.size()==1 && close==null — close_day/close_time null, is_24h=true
 *   4. 영업시간 정보 없음: periods null or empty → 빈 리스트 반환 (신규/미입력 장소)
 */
final class OpeningHoursParser {

    private OpeningHoursParser() {}

    static List<PlaceOpeningPeriod> parse(Long placeId,
                                          GoogleOpeningHours hours,
                                          OffsetDateTime sourceRefreshedAt) {
        if (hours == null || hours.getPeriods() == null || hours.getPeriods().isEmpty()) {
            return Collections.emptyList();
        }

        List<Period> periods = hours.getPeriods();

        // 24/7 판별: period가 1개이고 close가 null
        if (periods.size() == 1 && periods.get(0).getClose() == null) {
            TimePoint open = periods.get(0).getOpen();
            return List.of(PlaceOpeningPeriod.builder()
                    .placeId(placeId)
                    .openDay((short) open.getDay())
                    .openTime(LocalTime.of(open.getHour(), open.getMinute()))
                    .closeDay(null)
                    .closeTime(null)
                    .is24h(true)
                    .sourceRefreshedAt(sourceRefreshedAt)
                    .build());
        }

        return periods.stream()
                .filter(p -> p.getOpen() != null)
                .map(p -> toPeriodEntity(placeId, p, sourceRefreshedAt))
                .toList();
    }

    private static PlaceOpeningPeriod toPeriodEntity(Long placeId, Period p,
                                                      OffsetDateTime sourceRefreshedAt) {
        TimePoint open = p.getOpen();
        TimePoint close = p.getClose();

        Short closeDay = close != null ? (short) close.getDay() : null;
        LocalTime closeTime = close != null
                ? LocalTime.of(close.getHour(), close.getMinute())
                : null;

        return PlaceOpeningPeriod.builder()
                .placeId(placeId)
                .openDay((short) open.getDay())
                .openTime(LocalTime.of(open.getHour(), open.getMinute()))
                .closeDay(closeDay)
                .closeTime(closeTime)
                .is24h(false)
                .sourceRefreshedAt(sourceRefreshedAt)
                .build();
    }
}
