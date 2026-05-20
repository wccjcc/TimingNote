package com.timingnote.api.domain.notification.service;

import com.timingnote.api.domain.notification.dto.response.GeofenceSlotItemResponseDto;
import com.timingnote.api.domain.notification.dto.response.GeofenceSlotsResponseDto;
import com.timingnote.api.domain.notification.entity.GeofenceSlot;
import com.timingnote.api.domain.notification.repository.GeofenceSlotRepository;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.settings.repository.UserSettingsRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class GeofenceSlotQueryServiceImpl implements GeofenceSlotQueryService {

    private static final int DEFAULT_RADIUS_M = 200;

    private final GeofenceSlotRepository geofenceSlotRepository;
    private final PlaceRepository placeRepository;
    private final UserSettingsRepository userSettingsRepository;

    @Override
    @Transactional(readOnly = true)
    public GeofenceSlotsResponseDto getActiveSlots(Long userId) {
        OffsetDateTime lastCalculatedAt = geofenceSlotRepository.findLastCalculatedAtByUserId(userId).orElse(null);

        int radiusM = userSettingsRepository.findTopByUserIdOrderByUpdatedAtDesc(userId)
                .map(s -> s.getRadiusM() == null ? DEFAULT_RADIUS_M : s.getRadiusM())
                .orElse(DEFAULT_RADIUS_M);

        List<GeofenceSlot> activeSlots = geofenceSlotRepository.findByUserIdAndActiveTrue(userId);
        Map<Long, Place> placeById = placeRepository.findAllById(
                        activeSlots.stream().map(GeofenceSlot::getPlaceId).distinct().toList())
                .stream()
                .collect(Collectors.toMap(Place::getId, Function.identity()));

        List<GeofenceSlotItemResponseDto> slots = activeSlots.stream()
                .map(slot -> GeofenceSlotItemResponseDto.from(slot, placeById.get(slot.getPlaceId()), radiusM))
                .toList();

        return GeofenceSlotsResponseDto.builder()
                .lastCalculatedAt(lastCalculatedAt)
                .slots(slots)
                .build();
    }
}
