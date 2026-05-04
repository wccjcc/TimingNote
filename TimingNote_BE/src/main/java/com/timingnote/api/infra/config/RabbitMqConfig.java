package com.timingnote.api.infra.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.retry.backoff.ExponentialBackOffPolicy;
import org.springframework.retry.policy.SimpleRetryPolicy;
import org.springframework.retry.support.RetryTemplate;

@Configuration
public class RabbitMqConfig {

    // 재계산 요청을 받는 메인 큐 이름
    @Value("${app.rabbitmq.geofence-slot-recalculate-queue:geofence.slot.recalculate}")
    private String geofenceQueueName;

    // 메인 큐와 DLQ를 라우팅할 익스체인지 이름
    @Value("${app.rabbitmq.geofence-slot-exchange:geofence.slot.exchange}")
    private String geofenceExchangeName;

    // 메인 큐 라우팅 키
    @Value("${app.rabbitmq.geofence-slot-routing-key:geofence.slot.recalculate}")
    private String geofenceRoutingKey;

    // 데드레터 큐 이름
    @Value("${app.rabbitmq.geofence-slot-dlq:geofence.slot.recalculate.dlq}")
    private String geofenceDlqName;

    // 데드레터 큐 라우팅 키
    @Value("${app.rabbitmq.geofence-slot-dlq-routing-key:geofence.slot.recalculate.dlq}")
    private String geofenceDlqRoutingKey;

    // 리스너 동시성(최소/최대), prefetch, 재시도 횟수
    @Value("${app.rabbitmq.geofence-slot-concurrency:2}")
    private int concurrency;

    @Value("${app.rabbitmq.geofence-slot-max-concurrency:6}")
    private int maxConcurrency;

    @Value("${app.rabbitmq.geofence-slot-prefetch:20}")
    private int prefetch;

    @Value("${app.rabbitmq.geofence-slot-retry-max-attempts:3}")
    private int retryMaxAttempts;

    @Value("${app.rabbitmq.geofence-slot-retry-initial-interval-ms:1000}")
    private long retryInitialIntervalMs;

    @Value("${app.rabbitmq.geofence-slot-retry-max-interval-ms:10000}")
    private long retryMaxIntervalMs;

    @Value("${app.rabbitmq.geofence-slot-retry-multiplier:2.0}")
    private double retryMultiplier;

    @Bean
    public DirectExchange geofenceExchange() {
        return new DirectExchange(geofenceExchangeName, true, false);
    }

    @Bean
    public Queue geofenceQueue() {
        // 메인 큐에서 처리 실패(재시도 소진 + reject)된 메시지는 DLQ로 이동한다.
        return new Queue(geofenceQueueName, true, false, false, java.util.Map.of(
                "x-dead-letter-exchange", geofenceExchangeName,
                "x-dead-letter-routing-key", geofenceDlqRoutingKey
        ));
    }

    @Bean
    public Queue geofenceDlq() {
        return new Queue(geofenceDlqName, true);
    }

    @Bean
    public Binding geofenceBinding(Queue geofenceQueue, DirectExchange geofenceExchange) {
        return BindingBuilder.bind(geofenceQueue).to(geofenceExchange).with(geofenceRoutingKey);
    }

    @Bean
    public Binding geofenceDlqBinding(Queue geofenceDlq, DirectExchange geofenceExchange) {
        return BindingBuilder.bind(geofenceDlq).to(geofenceExchange).with(geofenceDlqRoutingKey);
    }

    @Bean
    public Jackson2JsonMessageConverter jackson2JsonMessageConverter() {
        // Event DTO(record)를 JSON으로 직렬화/역직렬화하기 위한 컨버터
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RetryTemplate geofenceRetryTemplate() {
        // 컨슈머 예외 발생 시 즉시 포기하지 않고 지정 횟수만큼 지수 백오프로 재시도한다.
        RetryTemplate retryTemplate = new RetryTemplate();
        retryTemplate.setRetryPolicy(new SimpleRetryPolicy(retryMaxAttempts));

        ExponentialBackOffPolicy backOffPolicy = new ExponentialBackOffPolicy();
        backOffPolicy.setInitialInterval(retryInitialIntervalMs);
        backOffPolicy.setMaxInterval(retryMaxIntervalMs);
        backOffPolicy.setMultiplier(retryMultiplier);
        retryTemplate.setBackOffPolicy(backOffPolicy);
        return retryTemplate;
    }

    @Bean
    public SimpleRabbitListenerContainerFactory geofenceRabbitListenerContainerFactory(
            ConnectionFactory connectionFactory,
            Jackson2JsonMessageConverter messageConverter,
            RetryTemplate geofenceRetryTemplate
    ) {
        // Geofence 전용 리스너 설정:
        // - 동시성/Prefetch 튜닝
        // - JSON 컨버터 적용
        // - 재시도 정책 적용
        // - 재시도 실패 시 requeue 하지 않고 reject -> DLQ 이동
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(messageConverter);
        factory.setConcurrentConsumers(concurrency);
        factory.setMaxConcurrentConsumers(maxConcurrency);
        factory.setPrefetchCount(prefetch);
        factory.setDefaultRequeueRejected(false);
        factory.setAdviceChain(org.springframework.amqp.rabbit.config.RetryInterceptorBuilder.stateless()
                .retryOperations(geofenceRetryTemplate)
                .recoverer((message, cause) -> {
                    message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                    throw new org.springframework.amqp.AmqpRejectAndDontRequeueException(
                            "Geofence slot message failed and moved to DLQ", cause
                    );
                })
                .build());
        return factory;
    }

    @Bean
    public RabbitAdmin rabbitAdmin(ConnectionFactory connectionFactory) {
        // 앱 시작 시 Queue/Exchange/Binding을 자동 선언한다.
        RabbitAdmin rabbitAdmin = new RabbitAdmin(connectionFactory);
        rabbitAdmin.setAutoStartup(true);
        return rabbitAdmin;
    }
}

