package com.timingnote.api.infra.client.google;

import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchRequest;
import com.timingnote.api.infra.client.google.dto.GoogleNearbySearchResponse;
import com.timingnote.api.infra.client.google.dto.GoogleTextSearchRequest;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.service.annotation.HttpExchange;
import org.springframework.web.service.annotation.PostExchange;
import reactor.core.publisher.Mono;

@HttpExchange("/v1/places")
public interface GooglePlacesClient {

    @PostExchange(":searchNearby")
    Mono<GoogleNearbySearchResponse> searchNearby(@RequestBody GoogleNearbySearchRequest request);

    @PostExchange(":searchText")
    Mono<GoogleNearbySearchResponse> searchText(@RequestBody GoogleTextSearchRequest request);
}
