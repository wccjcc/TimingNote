package com.timingnote.api.infra.client.google.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class GoogleNearbySearchRequest {

    private LocationRestriction locationRestriction;
    private List<String> includedTypes;
    private int maxResultCount;

    @Getter
    @Builder
    public static class LocationRestriction {
        private Circle circle;
    }

    @Getter
    @Builder
    public static class Circle {
        private LatLng center;
        private double radius;
    }

    @Getter
    @Builder
    public static class LatLng {
        private double latitude;
        private double longitude;
    }
}
