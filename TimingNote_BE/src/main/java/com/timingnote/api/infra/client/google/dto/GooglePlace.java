package com.timingnote.api.infra.client.google.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class GooglePlace {

    private String id; // Google Place ID
    private GoogleDisplayName displayName;
    private GoogleOpeningHours regularOpeningHours;
    private LatLng location; // Text Search 응답에 포함

    // 가게 운영 상태: OPERATIONAL | CLOSED_TEMPORARILY | CLOSED_PERMANENTLY | IN_CONSTRUCTION
    private String businessStatus;

    // 현지 시각 = UTC + utcOffsetMinutes. 한국은 항상 540(UTC+9)
    private Integer utcOffsetMinutes;

    @Getter
    @NoArgsConstructor
    public static class LatLng {
        private double latitude;
        private double longitude;
    }
}
