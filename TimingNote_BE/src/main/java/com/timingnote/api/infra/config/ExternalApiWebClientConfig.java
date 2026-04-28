package com.timingnote.api.infra.config;

import com.timingnote.api.infra.client.google.GooglePlacesClient;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.support.WebClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;

@Configuration
public class ExternalApiWebClientConfig {

    @Value("${kakao.api.key}")
    private String kakaoApiKey;

    @Value("${google.places.api.key}")
    private String googleApiKey;

    @Bean
    public KakaoLocalClient kakaoLocalClient() {
        WebClient webClient = WebClient.builder()
                .baseUrl("https://dapi.kakao.com")
                .defaultHeader("Authorization", "KakaoAK " + kakaoApiKey)
                .build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
                .builderFor(WebClientAdapter.create(webClient))
                .build();
        return factory.createClient(KakaoLocalClient.class);
    }

    @Bean
    public GooglePlacesClient googlePlacesClient() {
        WebClient webClient = WebClient.builder()
                .baseUrl("https://places.googleapis.com")
                .defaultHeader("X-Goog-Api-Key", googleApiKey)
                .defaultHeader("X-Goog-FieldMask", "places.id,places.displayName,places.location,places.regularOpeningHours,places.businessStatus,places.utcOffsetMinutes")
                .build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
                .builderFor(WebClientAdapter.create(webClient))
                .build();
        return factory.createClient(GooglePlacesClient.class);
    }
}
