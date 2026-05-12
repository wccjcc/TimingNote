package com.timingnote.api.infra.config;

import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 웹 인터셉터 등록 설정
 */
@Configuration
@RequiredArgsConstructor
public class WebMvcConfig implements WebMvcConfigurer {

    private final DeviceSecretAuthInterceptor deviceSecretAuthInterceptor;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true);
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(deviceSecretAuthInterceptor)
                .addPathPatterns("/api/v1/**")
                // 디바이스 등록 API는 인증 전 호출되어야 하므로 제외
                .excludePathPatterns("/api/v1/users")
                // 관리자 엔드포인트는 X-Admin-Secret 자체 검증 — 디바이스 인증 우회
                .excludePathPatterns("/api/v1/admin/**")
                .excludePathPatterns("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html", "/error");
    }
}
