package com.timingnote.api.domain.todo.dto.response;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;

@Getter
@Builder
@Schema(description = "후보 장소 — 사용자 가시성 + 알림 디버깅용")
public class CandidatePlaceResponse {

    @Schema(description = "후보 ID (todo_candidate_places.id)")
    private Long candidateId;

    @Schema(description = "장소 정보")
    private TodoDetailResponse.PlaceResponse place;

    @Schema(description = "후보 계산 시점의 사용자-장소 거리(m)")
    private Integer distanceM;

    @Schema(description = "지오펜스 등록 대상 여부 (사용자 명시 제외 등에 사용 — 슬롯 활성 여부와는 다른 축)")
    private boolean monitoringTarget;

    @Schema(description = "현재 활성 슬롯에 등록되어 있는지 (geofence_slots.is_active=true)")
    private boolean activeSlot;

    @Schema(description = "후보 계산(저장) 시각")
    private OffsetDateTime calculatedAt;

    @Schema(description = "후보 만료 시각 (null=유효)")
    private OffsetDateTime expiresAt;

    // score 필드 제거: GeofenceSlotManagerImpl이 계산한 점수는 정렬·top-N 선택에만 쓰이고 DB에
    // 저장되지 않아 todo_candidate_places.score 컬럼은 항상 null. 응답 노출 의미가 없어 정리함.
    // DB 컬럼 자체는 마이그레이션 리스크로 일단 유지.

    public static CandidatePlaceResponse from(TodoCandidatePlace c, boolean isActiveSlot) {
        Place p = c.getPlace();
        TodoDetailResponse.PlaceResponse placeDto = TodoDetailResponse.PlaceResponse.builder()
                .id(p.getId())
                .externalPlaceId(p.getExternalPlaceId())
                .name(p.getName())
                .address(p.getAddress())
                .roadAddress(p.getRoadAddress())
                .phone(p.getPhone())
                .categoryGroupCode(p.getCategoryGroupCode())
                .categoryGroupName(p.getCategoryGroupName())
                .businessStatus(p.getBusinessStatus())
                .placeUrl(p.getPlaceUrl())
                .latitude(p.getLatitude())
                .longitude(p.getLongitude())
                .build();

        return CandidatePlaceResponse.builder()
                .candidateId(c.getId())
                .place(placeDto)
                .distanceM(c.getDistanceM())
                .monitoringTarget(c.isMonitoringTarget())
                .activeSlot(isActiveSlot)
                .calculatedAt(c.getCalculatedAt())
                .expiresAt(c.getExpiresAt())
                .build();
    }
}
