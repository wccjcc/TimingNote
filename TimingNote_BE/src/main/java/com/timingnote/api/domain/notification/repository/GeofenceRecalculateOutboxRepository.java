package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.GeofenceOutboxStatus;
import com.timingnote.api.domain.notification.entity.GeofenceRecalculateOutbox;
import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GeofenceRecalculateOutboxRepository extends JpaRepository<GeofenceRecalculateOutbox, Long> {

    List<GeofenceRecalculateOutbox> findByStatusInAndNextRetryAtLessThanEqualOrderByIdAsc(
            Collection<GeofenceOutboxStatus> statuses,
            OffsetDateTime nextRetryAt,
            Pageable pageable
    );
}

