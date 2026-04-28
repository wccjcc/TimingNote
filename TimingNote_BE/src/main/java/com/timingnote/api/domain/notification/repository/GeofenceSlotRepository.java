package com.timingnote.api.domain.notification.repository;

import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GeofenceSlotRepository extends JpaRepository<GeofenceSlot, Long> {
}
