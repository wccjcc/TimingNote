package com.timingnote.api.infra.client.google;

import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchResponse;
import com.timingnote.api.infra.client.google.dto.GooglePlace;
import com.timingnote.api.infra.client.google.dto.GoogleTextSearchRequest;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.service.annotation.GetExchange;
import org.springframework.web.service.annotation.HttpExchange;
import org.springframework.web.service.annotation.PostExchange;
import reactor.core.publisher.Mono;

@HttpExchange("/v1/places")
public interface GooglePlacesClient {

    @PostExchange(":searchText")
    Mono<GoogleNearbySearchResponse> searchText(@RequestBody GoogleTextSearchRequest request);

    @GetExchange("/{placeId}")
    Mono<GooglePlace> getPlaceDetails(
            @PathVariable String placeId,
            @RequestHeader("X-Goog-FieldMask") String fieldMask);
}
