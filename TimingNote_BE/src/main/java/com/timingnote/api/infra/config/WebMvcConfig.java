package com.timingnote.api.infra.config;

import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
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
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(deviceSecretAuthInterceptor)
                .addPathPatterns("/api/v1/**")
                // 디바이스 등록 API는 인증 전 호출되어야 하므로 제외
                .excludePathPatterns("/api/v1/users")
                .excludePathPatterns("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html", "/error");
    }
}
