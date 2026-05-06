package com.timingnote.api.infra.client.google.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class GoogleOpeningHours {

    private Boolean openNow;
    private List<Period> periods;
    private List<String> weekdayDescriptions;

    @Getter
    @NoArgsConstructor
    public static class Period {
        private TimePoint open;
        private TimePoint close;
    }

    @Getter
    @NoArgsConstructor
    public static class TimePoint {
        private int day;    // 0=일, 1=월, ..., 6=토
        private int hour;
        private int minute;
    }
}
