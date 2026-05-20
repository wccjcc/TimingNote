package com.timingnote.api.domain.notification.dto.response;

import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.place.entity.Place;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class GeofenceSlotItemResponseDto {

    private Long slotId;
    private Long todoId;
    private Long placeId;
    private Double latitude;
    private Double longitude;
    private Integer radiusM;
    private boolean active;
    private OffsetDateTime calculatedAt;

    public static GeofenceSlotItemResponseDto from(GeofenceSlot slot, Place place, Integer radiusM) {
        return GeofenceSlotItemResponseDto.builder()
                .slotId(slot.getId())
                .todoId(slot.getTodoId())
                .placeId(slot.getPlaceId())
                .latitude(place != null ? place.getLatitude() : null)
                .longitude(place != null ? place.getLongitude() : null)
                .radiusM(radiusM)
                .active(slot.isActive())
                .calculatedAt(slot.getCalculatedAt())
                .build();
    }
}

