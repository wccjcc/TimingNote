package com.timingnote.api.domain.settings.repository;

import com.timingnote.api.domain.settings.entity.UserSettings;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserSettingsRepository extends JpaRepository<UserSettings, Long> {

    Optional<UserSettings> findTopByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<UserSettings> findTopByUserIdOrderByUpdatedAtDesc(Long userId);
}
