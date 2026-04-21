package com.timingnote.api.infra.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.util.StringUtils;

@Configuration
public class SwaggerConfig {

        @Value("${server.port}")
        private String port;

        @Value("${spring.application.name}")
        private String serviceName;

        @Value("${swagger.server-url:}")
        private String swaggerServerUrl;

        @Bean
        @Primary
        public OpenAPI openAPI() {
                String serverUrl = StringUtils.hasText(swaggerServerUrl)
                                ? swaggerServerUrl
                                : "http://localhost:" + port;

                return new OpenAPI()
                                .components(new Components()
                                                .addSecuritySchemes("userIdHeader", new SecurityScheme()
                                                                .name("X-User-Id")
                                                                .type(SecurityScheme.Type.APIKEY)
                                                                .in(SecurityScheme.In.HEADER)
                                                                .description("Gateway injects this header after JWT validation.")))
                                .addSecurityItem(new SecurityRequirement().addList("userIdHeader"))
                                .info(new Info()
                                                .title("TimingNote REST API : " + serviceName)
                                                .description("TimingNote 프로젝트를 위한 REST API 문서입니다.")
                                                .version("V1_0421"))
                                .addServersItem(new Server().url(serverUrl).description("TimingNote Server"));
        }
}
