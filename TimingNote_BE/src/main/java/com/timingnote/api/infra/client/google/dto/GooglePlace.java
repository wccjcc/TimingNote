package com.timingnote.api.infra.client.google.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class GooglePlace {

    private String id;
    private GoogleDisplayName displayName;
    private GoogleOpeningHours regularOpeningHours;
    private LatLng location;
    private String businessStatus;
    private String nationalPhoneNumber;

    @Getter
    @NoArgsConstructor
    public static class LatLng {
        private double latitude;
        private double longitude;
    }
}
