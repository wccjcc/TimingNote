package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.UserNotification;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserNotificationRepository extends JpaRepository<UserNotification, Long> {

    Page<UserNotification> findByUserId(Long userId, Pageable pageable);

    Page<UserNotification> findByUserIdAndTodoId(Long userId, Long todoId, Pageable pageable);

    Optional<UserNotification> findByIdAndUserId(Long id, Long userId);
}
