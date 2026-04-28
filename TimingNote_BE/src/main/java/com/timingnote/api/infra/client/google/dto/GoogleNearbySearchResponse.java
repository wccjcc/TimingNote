package com.timingnote.api.infra.client.google.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class GoogleNearbySearchResponse {

    private List<GooglePlace> places;
}
