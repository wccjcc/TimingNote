package com.timingnote.api.domain.user.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.user.dto.request.UserRegisterRequestDto;
import com.timingnote.api.domain.user.dto.response.UserRegisterResponseDto;
import com.timingnote.api.domain.user.entity.User;
import com.timingnote.api.domain.user.repository.UserRepository;
import com.timingnote.api.infra.security.DeviceSecretManager;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final DeviceSecretManager deviceSecretManager;

    /**
     * SYS-01 디바이스 등록:
     * installationUuid 기준으로 사용자를 생성한다.
     * 이미 등록된 installationUuid는 기존 deviceSecret을 계속 사용해야 하므로 재발급하지 않고 충돌을 반환한다.
     */
    @Override
    @Transactional
    public UserRegisterResponseDto registerDevice(UserRegisterRequestDto requestDto) {
        //request에서 uuid 추출
        UUID installationUuid = parseInstallationUuid(requestDto.getInstallationUuid());

        //이미 있는 uuid라면, UUID_CONFLICT 에러 응답
        if (userRepository.findByInstallationUuid(installationUuid).isPresent()) {
            throw new BusinessException(ErrorCode.UUID_CONFLICT);
        }

        //DeviceSecret 생성
        String rawDeviceSecret = deviceSecretManager.generateRawSecret();
        //DeviceSecret 해시
        String hashedDeviceSecret = deviceSecretManager.hash(rawDeviceSecret);
        //User에 저장
        User user = userRepository.save(new User(installationUuid, hashedDeviceSecret));

        return UserRegisterResponseDto.builder()
                .userId(user.getId())
                .deviceSecret(rawDeviceSecret)
                .createdAt(user.getCreatedAt().toInstant().toString())
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
