package com.timingnote.api.domain.notification.dto.response;

import java.time.OffsetDateTime;
import java.util.List;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class GeofenceSlotsResponseDto {

    private OffsetDateTime lastCalculatedAt;
    private List<GeofenceSlotItemResponseDto> slots;
}

