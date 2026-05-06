package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.response.GeofenceSlotItemResponseDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceSlotsResponseDto;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import java.time.OffsetDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class GeofenceSlotQueryServiceImpl implements GeofenceSlotQueryService {

    private final GeofenceSlotRepository geofenceSlotRepository;

    @Override
    @Transactional(readOnly = true)
    public GeofenceSlotsResponseDto getActiveSlots(Long userId) {
        OffsetDateTime lastCalculatedAt = geofenceSlotRepository.findLastCalculatedAtByUserId(userId).orElse(null);
        List<GeofenceSlotItemResponseDto> slots = geofenceSlotRepository.findByUserIdAndActiveTrue(userId).stream()
                .map(GeofenceSlotItemResponseDto::from)
                .toList();
        return GeofenceSlotsResponseDto.builder()
                .lastCalculatedAt(lastCalculatedAt)
                .slots(slots)
                .build();
    }
}
