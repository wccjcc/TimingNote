package com.timingnote.api.infra.security;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.user.entity.User;
import com.timingnote.api.domain.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * X-Device-Secret 인증 인터셉터
 */
@Component
@RequiredArgsConstructor
public class DeviceSecretAuthInterceptor implements HandlerInterceptor {

    public static final String DEVICE_SECRET_HEADER = "X-Device-Secret";
    public static final String AUTHENTICATED_USER_ID = "authenticatedUserId";

    private final UserRepository userRepository;
    private final DeviceSecretManager deviceSecretManager;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // CORS preflight 요청은 인증 헤더 없이 들어오므로 통과시킨다.
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String rawSecret = request.getHeader(DEVICE_SECRET_HEADER);
        if (!StringUtils.hasText(rawSecret)) {
            throw new BusinessException("X-Device-Secret 헤더가 필요합니다.", ErrorCode.MISSING_REQUEST_HEADER);
        }

        String hashedSecret = deviceSecretManager.hash(rawSecret);
        User user = userRepository.findByDeviceSecret(hashedSecret)
                .orElseThrow(() -> new BusinessException("유효하지 않은 디바이스 시크릿입니다.", ErrorCode.UNAUTHORIZED));

        // 후속 레이어에서 사용자 식별이 필요할 때 사용할 수 있도록 request attribute에 보관
        request.setAttribute(AUTHENTICATED_USER_ID, user.getId());

        // 활동 시각 갱신
        user.updateLastSeenAt(OffsetDateTime.now(ZoneOffset.UTC));
        userRepository.save(user);

        return true;
    }
}
