package com.timingnote.api.domain.notification.dto.response;

import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class GeofenceSlotItemResponseDto {

    private Long slotId;
    private Long todoId;
    private Long placeId;
    private boolean active;
    private OffsetDateTime calculatedAt;

    public static GeofenceSlotItemResponseDto from(GeofenceSlot slot) {
        return GeofenceSlotItemResponseDto.builder()
                .slotId(slot.getId())
                .todoId(slot.getTodoId())
                .placeId(slot.getPlaceId())
                .active(slot.isActive())
                .calculatedAt(slot.getCalculatedAt())
                .build();
    }
}

