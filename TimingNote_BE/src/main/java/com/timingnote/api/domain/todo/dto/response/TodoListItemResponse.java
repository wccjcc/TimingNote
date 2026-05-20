package com.timingnote.api.domain.todo.dto.response;

import com.timingnote.api.domain.todo.entity.Todo;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;

@Getter
@Builder
@Schema(description = "할 일 목록 항목")
public class TodoListItemResponse {

    @Schema(description = "할 일 ID")
    private Long id;

    @Schema(description = "입력 유형", allowableValues = {"TEXT", "VOICE", "IMAGE", "LINK"})
    private String inputType;

    @Schema(description = "원문 내용")
    private String content;

    @Schema(description = "할 일 유형", allowableValues = {"SPECIFIC", "GENERIC", "ALIAS", "GENERAL"})
    private String todoType;

    @Schema(description = "진행 상태", allowableValues = {"ACTIVE", "DONE"})
    private String status;

    @Schema(description = "AI 구조화 상태", allowableValues = {"PENDING", "READY", "FAILED"})
    private String structureStatus;

    @Schema(description = "카테고리")
    private String category;

    @Schema(description = "장소 표시 레이블 (구조화 완료 후 설정)")
    private String resolvedPlaceLabel;

    @Schema(description = "주 장소 위도 — primaryPlaceId가 있을 때만 존재 (GENERIC/매칭 미완은 null)")
    private Double placeLatitude;

    @Schema(description = "주 장소 경도 — primaryPlaceId가 있을 때만 존재 (GENERIC/매칭 미완은 null)")
    private Double placeLongitude;

    @Schema(description = "알림 활성화 여부")
    private boolean alertEnabled;

    @Schema(description = "현재 활성 슬롯에 등록되어 있는지 (geofence_slots.is_active=true)")
    private boolean activeSlot;

    @Schema(description = "완료 시각")
    private OffsetDateTime completedAt;

    @Schema(description = "생성 시각")
    private OffsetDateTime createdAt;

    @Schema(description = "대표 이미지 URL (이미지 입력이 있을 때만 존재)")
    private String thumbnailUrl;

    public static TodoListItemResponse from(Todo todo, String thumbnailUrl,
                                            Double placeLatitude, Double placeLongitude,
                                            boolean activeSlot) {
        return TodoListItemResponse.builder()
                .id(todo.getId())
                .inputType(todo.getInputType())
                .content(todo.getContent())
                .todoType(todo.getTodoType())
                .status(todo.getStatus())
                .structureStatus(todo.getStructureStatus())
                .category(todo.getCategory())
                .resolvedPlaceLabel(todo.getResolvedPlaceLabel())
                .placeLatitude(placeLatitude)
                .placeLongitude(placeLongitude)
                .alertEnabled(todo.isAlertEnabled())
                .activeSlot(activeSlot)
                .completedAt(todo.getCompletedAt())
                .createdAt(todo.getCreatedAt())
                .thumbnailUrl(thumbnailUrl)
                .build();
    }
}
