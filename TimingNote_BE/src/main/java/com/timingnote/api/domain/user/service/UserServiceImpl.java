package com.timingnote.api.domain.user.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.user.dto.request.UserRegisterRequestDto;
import com.timingnote.api.domain.user.dto.response.UserRegisterResponseDto;
import com.timingnote.api.domain.user.entity.User;
import com.timingnote.api.domain.user.repository.UserRepository;
import com.timingnote.api.infra.security.DeviceSecretManager;

import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.services.s3.endpoints.internal.Value;

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final DeviceSecretManager deviceSecretManager;

    /**
     * SYS-01 디바이스 등록:
     * installationUuid 기준으로 사용자를 생성한다.
     * 이미 등록된 installationUuid의 경우 deviceSecret을 재발급 한 뒤 저장한다.
     */
    @Override
    @Transactional
    public UserRegisterResponseDto registerDevice(UserRegisterRequestDto requestDto) {
        //request에서 uuid 추출
        UUID installationUuid = parseInstallationUuid(requestDto.getInstallationUuid());

        //항상 새 device secret 발급
        //DeviceSecret 생성
        String rawDeviceSecret = deviceSecretManager.generateRawSecret();
        //DeviceSecret 해시
        String hashedDeviceSecret = deviceSecretManager.hash(rawDeviceSecret);

        Optional<User> existingUserOpt = userRepository.findByInstallationUuid(installationUuid);

        final boolean isNewUser;
        final User user;

        if (existingUserOpt.isPresent()) {
            User existing = existingUserOpt.get();
            existing.updateDeviceSecret(hashedDeviceSecret);
            user = userRepository.save(existing);
            isNewUser = false;
        } else {
            User newUser = new User(installationUuid, hashedDeviceSecret);
            user = userRepository.save(newUser);
            isNewUser = true;
        }

        return UserRegisterResponseDto.builder()
                .userId(user.getId())
                .deviceSecret(rawDeviceSecret)
                .createdAt(user.getCreatedAt().toInstant().toString())
                .isNewUser(isNewUser)
                .build();
    }

    //uuid 파싱
    private UUID parseInstallationUuid(String installationUuid) {
        try {
            return UUID.fromString(installationUuid);
        } catch (IllegalArgumentException ex) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
    }
}
