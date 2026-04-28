package com.timingnote.api.infra.client.google.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class GoogleTextSearchRequest {

    private String textQuery;
    private LocationBias locationBias;
    private Integer pageSize;
    private String languageCode;

    @Getter
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class LocationBias {
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
