package com.timingnote.api.domain.user.repository;

import com.timingnote.api.domain.user.entity.User;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByInstallationUuid(UUID installationUuid);

    Optional<User> findByDeviceSecret(String deviceSecret);
}
