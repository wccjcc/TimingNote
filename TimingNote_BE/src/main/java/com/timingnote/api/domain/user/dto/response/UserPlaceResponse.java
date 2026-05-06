package com.timingnote.api.domain.user.dto.response;

import com.timingnote.api.domain.user.entity.UserPlace;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@Schema(description = "내 장소 응답")
public class UserPlaceResponse {

    @Schema(description = "내 장소 ID")
    private Long id;

    @Schema(description = "장소 별칭", example = "집")
    private String aliasName;

    @Schema(description = "장소 ID (places 테이블)")
    private Long placeId;

    @Schema(description = "장소명", example = "서울역")
    private String placeName;

    @Schema(description = "도로명 주소")
    private String roadAddress;

    @Schema(description = "지번 주소")
    private String address;

    @Schema(description = "위도 (latitude)")
    private Double latitude;

    @Schema(description = "경도 (longitude)")
    private Double longitude;

    @Schema(description = "등록 일시")
    private OffsetDateTime createdAt;

    public static UserPlaceResponse from(UserPlace userPlace) {
        return UserPlaceResponse.builder()
                .id(userPlace.getId())
                .aliasName(userPlace.getAliasName())
                .placeId(userPlace.getPlace().getId())
                .placeName(userPlace.getPlace().getName())
                .roadAddress(userPlace.getPlace().getRoadAddress())
                .address(userPlace.getPlace().getAddress())
                .latitude(userPlace.getPlace().getLatitude())
                .longitude(userPlace.getPlace().getLongitude())
                .createdAt(userPlace.getCreatedAt())
                .build();
    }
}
