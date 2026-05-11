package com.timingnote.api.infra.config;

import com.timingnote.api.infra.client.google.GooglePlacesClient;
import com.timingnote.api.infra.client.kakao.KakaoLocalClient;
import io.netty.channel.ChannelOption;
import io.netty.handler.timeout.ReadTimeoutHandler;
import io.netty.handler.timeout.WriteTimeoutHandler;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.reactive.function.client.support.WebClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;
import reactor.core.publisher.Mono;
import reactor.netty.http.client.HttpClient;
import reactor.util.retry.Retry;

@Slf4j
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
                .defaultHeader("X-Goog-FieldMask",
                        "places.id,places.displayName,places.location,"
                                + "places.regularOpeningHours,places.businessStatus,"
                                + "places.nationalPhoneNumber,places.primaryType,"
                                + "places.formattedAddress")
                .clientConnector(new ReactorClientHttpConnector(googleHttpClient()))
                .filter(googleRetry())
                .filter(googleErrorBodyLogger())
                .build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
                .builderFor(WebClientAdapter.create(webClient))
                .build();
        return factory.createClient(GooglePlacesClient.class);
    }

    /**
     * Google API 호출용 HttpClient — connect 5s, read/write 10s.
     * Google Places New API의 평균 응답 ~1s, 99p 3~5s. 여유 있게 잡되 무한 대기 방지.
     */
    private HttpClient googleHttpClient() {
        return HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5_000)
                .responseTimeout(Duration.ofSeconds(15))
                .doOnConnected(conn -> conn
                        .addHandlerLast(new ReadTimeoutHandler(10, TimeUnit.SECONDS))
                        .addHandlerLast(new WriteTimeoutHandler(10, TimeUnit.SECONDS)));
    }

    /**
     * Transient 5xx 및 connection 오류만 재시도 (4xx는 input 문제라 무의미).
     * 100ms부터 지수 백오프, 최대 2회 재시도.
     */
    private ExchangeFilterFunction googleRetry() {
        return (request, next) -> next.exchange(request)
                .flatMap(response -> {
                    if (response.statusCode().is5xxServerError()) {
                        return Mono.error(new TransientServerException(
                                "Google " + response.statusCode()));
                    }
                    return Mono.just(response);
                })
                .retryWhen(Retry.backoff(2, Duration.ofMillis(100))
                        .filter(t -> t instanceof TransientServerException
                                || t instanceof java.io.IOException
                                || t instanceof java.util.concurrent.TimeoutException)
                        .doBeforeRetry(s -> log.warn(
                                "[Google] 재시도 #{} ({}): {}",
                                s.totalRetries() + 1,
                                request.url(),
                                s.failure().getMessage())));
    }

    /** 재시도 대상 5xx 응답을 표현하기 위한 내부 예외. */
    private static class TransientServerException extends RuntimeException {
        TransientServerException(String msg) { super(msg); }
    }

    /**
     * Google Places API의 4xx/5xx 응답 본문을 로그로 노출하는 필터.
     *
     * 기존엔 WebClientResponseException 메시지(상태 코드만)만 캐치돼서 Google이
     * 보낸 INVALID_ARGUMENT 등 구체 사유를 알 수 없었다. 이 필터는 에러 응답의 body를
     * 읽어 로그에 찍은 뒤, 같은 body를 가진 WebClientResponseException으로 다시 던져
     * 호출처의 catch에서 `getResponseBodyAsString()`으로 읽을 수도 있게 한다.
     */
    private ExchangeFilterFunction googleErrorBodyLogger() {
        return (request, next) -> next.exchange(request).flatMap(response -> {
            if (!response.statusCode().isError()) {
                return Mono.just(response);
            }
            return response.bodyToMono(String.class)
                    .defaultIfEmpty("")
                    .flatMap(body -> {
                        log.warn("[Google] HTTP {} {} {} body={}",
                                response.statusCode().value(),
                                request.method(),
                                request.url(),
                                body);
                        return Mono.error(WebClientResponseException.create(
                                response.statusCode().value(),
                                response.statusCode().toString(),
                                response.headers().asHttpHeaders(),
                                body.getBytes(StandardCharsets.UTF_8),
                                StandardCharsets.UTF_8));
                    });
        });
    }
}
