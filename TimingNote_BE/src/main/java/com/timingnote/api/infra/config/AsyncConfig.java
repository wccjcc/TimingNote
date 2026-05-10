package com.timingnote.api.infra.config;

import java.util.Arrays;
import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.aop.interceptor.AsyncUncaughtExceptionHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * 비동기 처리 설정.
 *
 * <p>Google Places 영업시간 보강처럼 외부 호출이 길고 best-effort인 작업을
 * HTTP 응답 path에서 분리하기 위함. {@code @TransactionalEventListener(AFTER_COMMIT)}와
 * 결합해 트랜잭션 커밋 후에만 비동기로 실행되도록 한다.
 *
 * <p>스레드풀 동시성 = Google API 동시 호출 상한이므로 quota/timeout 고려해 보수적으로 설정.
 */
@Slf4j
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    /**
     * Google 영업시간 보강 전용 executor.
     * - core 8 / max 16: Google Places New API 동시 호출 ~16개로 제한
     * - queue 500: 1만 동접 스파이크 흡수 (메모리 점유 ~수MB 수준)
     * - 큐 만석 시 CallerRunsPolicy: 호출 스레드(보통 트랜잭션 커밋 직후 thread)가 직접 실행
     *   → drop 없이 자연 백프레셔
     */
    @Bean(name = "googleEnrichmentExecutor")
    public Executor googleEnrichmentExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);
        executor.setMaxPoolSize(16);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("google-enrich-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        // void 반환 @Async 메서드의 캐치되지 않은 예외 — 로그로만 남기고 삼킴
        return (throwable, method, params) -> log.error(
                "[Async] uncaught in {}.{}({}): {}",
                method.getDeclaringClass().getSimpleName(),
                method.getName(),
                Arrays.toString(params),
                throwable.getMessage(),
                throwable);
    }
}
