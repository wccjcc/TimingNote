package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.UserNotification;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserNotificationRepository extends JpaRepository<UserNotification, Long> {
}
