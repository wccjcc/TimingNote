package com.timingnote.api.infra.security;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.user.entity.User;
import com.timingnote.api.domain.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DeviceSecretAuthInterceptorTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private DeviceSecretManager deviceSecretManager;

    @Test
    void preHandlePassesOptionsRequestWithoutAuthentication() {
        // given
        DeviceSecretAuthInterceptor interceptor = new DeviceSecretAuthInterceptor(userRepository, deviceSecretManager);
        MockHttpServletRequest request = new MockHttpServletRequest("OPTIONS", "/api/v1/todos");

        // when
        boolean result = interceptor.preHandle(request, new MockHttpServletResponse(), new Object());

        // then
        assertThat(result).isTrue();
        verifyNoInteractions(deviceSecretManager, userRepository);
    }

    @Test
    void preHandleThrowsMissingHeaderWhenDeviceSecretIsBlank() {
        // given
        DeviceSecretAuthInterceptor interceptor = new DeviceSecretAuthInterceptor(userRepository, deviceSecretManager);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/todos");
        request.addHeader(DeviceSecretAuthInterceptor.DEVICE_SECRET_HEADER, " ");

        // when & then
        assertThatThrownBy(() -> interceptor.preHandle(request, new MockHttpServletResponse(), new Object()))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.MISSING_REQUEST_HEADER));
        verifyNoInteractions(deviceSecretManager, userRepository);
    }

    @Test
    void preHandleThrowsUnauthorizedWhenSecretDoesNotMatchUser() {
        // given
        DeviceSecretAuthInterceptor interceptor = new DeviceSecretAuthInterceptor(userRepository, deviceSecretManager);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/todos");
        request.addHeader(DeviceSecretAuthInterceptor.DEVICE_SECRET_HEADER, "raw-secret");
        when(deviceSecretManager.hash("raw-secret")).thenReturn("hashed-secret");
        when(userRepository.findByDeviceSecret("hashed-secret")).thenReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> interceptor.preHandle(request, new MockHttpServletResponse(), new Object()))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
        verify(userRepository, never()).save(org.mockito.ArgumentMatchers.any(User.class));
    }

    @Test
    void preHandleStoresAuthenticatedUserIdAndUpdatesLastSeenAt() {
        // given
        DeviceSecretAuthInterceptor interceptor = new DeviceSecretAuthInterceptor(userRepository, deviceSecretManager);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/todos");
        request.addHeader(DeviceSecretAuthInterceptor.DEVICE_SECRET_HEADER, "raw-secret");
        User user = new User(UUID.randomUUID(), "hashed-secret");
        ReflectionTestUtils.setField(user, "id", 7L);
        OffsetDateTime before = OffsetDateTime.now();

        when(deviceSecretManager.hash("raw-secret")).thenReturn("hashed-secret");
        when(userRepository.findByDeviceSecret("hashed-secret")).thenReturn(Optional.of(user));

        // when
        boolean result = interceptor.preHandle(request, new MockHttpServletResponse(), new Object());

        // then
        assertThat(result).isTrue();
        assertThat(request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID)).isEqualTo(7L);
        assertThat(user.getLastSeenAt()).isAfterOrEqualTo(before);
        verify(userRepository).save(user);
    }
}
