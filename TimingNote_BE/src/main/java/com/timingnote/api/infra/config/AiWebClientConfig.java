package com.timingnote.api.infra.config;

import com.timingnote.api.infra.client.ai.AiClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.support.WebClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;

@Configuration
public class AiWebClientConfig {

    @Value("${ai.server.url}")
    private String aiServerUrl;

    @Value("${ai.internal.secret}")
    private String internalSecret;

    @Bean
    public WebClient aiWebClient() {
        return WebClient.builder()
                .baseUrl(aiServerUrl)
                .defaultHeader("X-Internal-Secret", internalSecret)
                .build();
    }

    @Bean
    public AiClient aiClient(WebClient aiWebClient) {
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
                .builderFor(WebClientAdapter.create(aiWebClient))
                .build();
        return factory.createClient(AiClient.class);
    }
}
