package com.timingnote.api.domain.todo.dto.response;

import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoStructure;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;

import java.time.OffsetDateTime;
import java.util.List;

@Getter
@Builder
@Schema(description = "할 일 상세")
public class TodoDetailResponse {

    @Schema(description = "할 일 ID")
    private Long id;

    @Schema(description = "원문 내용")
    private String content;

    @Schema(description = "입력 유형", allowableValues = {"TEXT", "VOICE", "IMAGE", "LINK"})
    private String inputType;

    @Schema(description = "할 일 유형", allowableValues = {"SPECIFIC", "GENERIC", "ALIAS", "GENERAL"})
    private String todoType;

    @Schema(description = "진행 상태", allowableValues = {"ACTIVE", "DONE"})
    private String status;

    @Schema(description = "AI 구조화 상태", allowableValues = {"PENDING", "READY", "FAILED"})
    private String structureStatus;

    @Schema(description = "카테고리")
    private String category;

    @Schema(description = "장소 표시 레이블")
    private String resolvedPlaceLabel;

    @Schema(description = "알림 활성화 여부")
    private boolean alertEnabled;

    @Schema(description = "스누즈 해제 시각")
    private OffsetDateTime snoozedUntil;

    @Schema(description = "완료 시각")
    private OffsetDateTime completedAt;

    @Schema(description = "생성 시각")
    private OffsetDateTime createdAt;

    @Schema(description = "수정 시각")
    private OffsetDateTime updatedAt;

    @Schema(description = "AI 구조화 결과 (structureStatus=READY 일 때 존재)")
    private StructureResponse structure;

    @Schema(description = "시간 조건 목록")
    private List<TodoTimeConditionResponse> timeConditions;

    @Schema(description = "연결된 주 장소 (primaryPlaceId 있을 때 존재)")
    private PlaceResponse primaryPlace;

    @Schema(description = "이미지 URL 목록 (최대 3개, 이미지 입력이 있을 때만 존재)")
    private List<String> imageUrls;

    @Schema(description = "링크 URL (LINK 입력이 있을 때만 존재)")
    private String sharedUrl;

    @Schema(description = "후보 장소 목록 (DB에 후보가 있으면 todoType 무관하게 포함, 만료된 후보는 제외)")
    private List<CandidatePlaceResponse> candidates;

    @Getter
    @Builder
    @Schema(description = "AI 구조화 결과")
    public static class StructureResponse {
        @Schema(description = "정제된 할 일 텍스트")
        private String todoText;
        @Schema(description = "장소 텍스트")
        private String placeText;
        @Schema(description = "장소 유형", allowableValues = {"SPECIFIC", "GENERIC", "ALIAS", "GENERAL"})
        private String placeType;
        @Schema(description = "시간 힌트 원문")
        private String timeHintText;
    }

    @Getter
    @Builder
    @Schema(description = "장소 정보")
    public static class PlaceResponse {
        private Long id;
        /// 카카오 장소 ID — FE에서 후보를 SPECIFIC으로 지정할 때 setTodoPlace API에 그대로 전달.
        /// 지도 핀(외부 ID 없음)은 null.
        private String externalPlaceId;
        private String name;
        private String address;
        private String roadAddress;
        private String phone;
        private String categoryGroupCode;
        private String categoryGroupName;
        private String businessStatus;
        private String placeUrl;
        private Double latitude;
        private Double longitude;
    }

    public static TodoDetailResponse of(Todo todo,
                                        TodoStructure structure,
                                        List<TodoTimeCondition> timeConditions,
                                        Place primaryPlace,
                                        List<String> imageUrls,
                                        String sharedUrl,
                                        List<CandidatePlaceResponse> candidates) {
        return TodoDetailResponse.builder()
                .id(todo.getId())
                .content(todo.getContent())
                .inputType(todo.getInputType())
                .todoType(todo.getTodoType())
                .status(todo.getStatus())
                .structureStatus(todo.getStructureStatus())
                .category(todo.getCategory())
                .resolvedPlaceLabel(todo.getResolvedPlaceLabel())
                .alertEnabled(todo.isAlertEnabled())
                .snoozedUntil(todo.getSnoozedUntil())
                .completedAt(todo.getCompletedAt())
                .createdAt(todo.getCreatedAt())
                .updatedAt(todo.getUpdatedAt())
                .structure(structure != null ? toStructureResponse(structure) : null)
                .timeConditions(timeConditions.stream()
                        .map(TodoTimeConditionResponse::from)
                        .toList())
                .primaryPlace(primaryPlace != null ? toPlaceResponse(primaryPlace) : null)
                .imageUrls(imageUrls)
                .sharedUrl(sharedUrl)
                .candidates(candidates)
                .build();
    }

    private static StructureResponse toStructureResponse(TodoStructure s) {
        return StructureResponse.builder()
                .todoText(s.getTodoText())
                .placeText(s.getPlaceText())
                .placeType(s.getPlaceType() != null ? s.getPlaceType().name() : null)
                .timeHintText(s.getTimeHintText())
                .build();
    }

    private static PlaceResponse toPlaceResponse(Place p) {
        return PlaceResponse.builder()
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
    }
}
