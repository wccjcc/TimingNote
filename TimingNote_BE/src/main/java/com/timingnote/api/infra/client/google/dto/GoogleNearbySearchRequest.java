package com.timingnote.api.infra.client.google.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class GoogleNearbySearchRequest {

    private LocationRestriction locationRestriction;
    private List<String> includedTypes;
    private Integer maxResultCount;
    private String languageCode;

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
