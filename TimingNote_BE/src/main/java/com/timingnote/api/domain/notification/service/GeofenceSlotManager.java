package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.request.GeofenceSlotRecalculateEvent;

public interface GeofenceSlotManager {

    void recalculateSlots(GeofenceSlotRecalculateEvent event);
}
