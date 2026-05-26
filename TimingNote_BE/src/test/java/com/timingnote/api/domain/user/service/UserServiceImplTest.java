package com.timingnote.api.domain.user.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.user.dto.request.UserRegisterRequestDto;
import com.timingnote.api.domain.user.dto.response.UserRegisterResponseDto;
import com.timingnote.api.domain.user.entity.User;
import com.timingnote.api.domain.user.repository.UserRepository;
import com.timingnote.api.infra.security.DeviceSecretManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

    private static final OffsetDateTime CREATED_AT = OffsetDateTime.parse("2026-05-26T01:02:03Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private DeviceSecretManager deviceSecretManager;

    @Test
    void registerDeviceCreatesNewUserWhenInstallationUuidDoesNotExist() {
        // given
        UUID installationUuid = UUID.randomUUID();
        UserServiceImpl service = new UserServiceImpl(userRepository, deviceSecretManager);
        when(deviceSecretManager.generateRawSecret()).thenReturn("raw-secret");
        when(deviceSecretManager.hash("raw-secret")).thenReturn("hashed-secret");
        when(userRepository.findByInstallationUuid(installationUuid)).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            ReflectionTestUtils.setField(user, "id", 1L);
            ReflectionTestUtils.setField(user, "createdAt", CREATED_AT);
            return user;
        });

        // when
        UserRegisterResponseDto response = service.registerDevice(request(installationUuid.toString()));

        // then
        assertThat(response.getUserId()).isEqualTo(1L);
        assertThat(response.getDeviceSecret()).isEqualTo("raw-secret");
        assertThat(response.getCreatedAt()).isEqualTo("2026-05-26T01:02:03Z");
        assertThat(response.getIsNewUser()).isTrue();

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        assertThat(userCaptor.getValue().getInstallationUuid()).isEqualTo(installationUuid);
        assertThat(userCaptor.getValue().getDeviceSecret()).isEqualTo("hashed-secret");
    }

    @Test
    void registerDeviceRefreshesDeviceSecretWhenInstallationUuidAlreadyExists() {
        // given
        UUID installationUuid = UUID.randomUUID();
        User existingUser = new User(installationUuid, "old-hashed-secret");
        ReflectionTestUtils.setField(existingUser, "id", 7L);
        ReflectionTestUtils.setField(existingUser, "createdAt", CREATED_AT);
        UserServiceImpl service = new UserServiceImpl(userRepository, deviceSecretManager);

        when(deviceSecretManager.generateRawSecret()).thenReturn("new-raw-secret");
        when(deviceSecretManager.hash("new-raw-secret")).thenReturn("new-hashed-secret");
        when(userRepository.findByInstallationUuid(installationUuid)).thenReturn(Optional.of(existingUser));
        when(userRepository.save(existingUser)).thenReturn(existingUser);

        // when
        UserRegisterResponseDto response = service.registerDevice(request(installationUuid.toString()));

        // then
        assertThat(response.getUserId()).isEqualTo(7L);
        assertThat(response.getDeviceSecret()).isEqualTo("new-raw-secret");
        assertThat(response.getCreatedAt()).isEqualTo("2026-05-26T01:02:03Z");
        assertThat(response.getIsNewUser()).isFalse();
        assertThat(existingUser.getDeviceSecret()).isEqualTo("new-hashed-secret");
        verify(userRepository).save(existingUser);
    }

    @Test
    void registerDeviceThrowsValidationErrorWhenInstallationUuidIsInvalid() {
        // given
        UserServiceImpl service = new UserServiceImpl(userRepository, deviceSecretManager);

        // when & then
        assertThatThrownBy(() -> service.registerDevice(request("not-a-uuid")))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.VALIDATION_ERROR));
        verifyNoInteractions(deviceSecretManager, userRepository);
    }

    private UserRegisterRequestDto request(String installationUuid) {
        UserRegisterRequestDto request = new UserRegisterRequestDto();
        ReflectionTestUtils.setField(request, "installationUuid", installationUuid);
        return request;
    }
}
