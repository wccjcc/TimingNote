package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.UserFcmToken;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserFcmTokenRepository extends JpaRepository<UserFcmToken, Long> {

    Optional<UserFcmToken> findByUserId(Long userId);

    Optional<UserFcmToken> findByFcmToken(String fcmToken);
}
