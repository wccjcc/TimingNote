package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
@Schema(description = "할 일 수정 요청 (변경할 필드만 포함, null = 유지)")
public class TodoUpdateRequest {

    @Size(max = 2000)
    @Schema(description = "메모 내용 (null = 유지)")
    private String content;

    @Schema(description = "카테고리 (null = 유지, \"\" = 제거)")
    private String category;

    @Schema(description = "GENERIC 장소명 (null = 유지, \"\" = 제거)")
    private String placeText;

    @Schema(description = "이미지 URL 목록 (null = 유지, [] = 전체 삭제)")
    private List<String> imageUrls;

    @Schema(description = "링크 URL (null = 유지, \"\" = 삭제)")
    private String sharedUrl;

    @Valid
    @Schema(description = "시간 조건 목록 (null = 유지, [] = 전체 삭제)")
    private List<TodoTimeConditionRequest> timeConditions;

    @Schema(description = "사용자 현재 위도 — placeText 변경 시 GENERIC 후보 검색에 사용 (선택)")
    private Double latitude;

    @Schema(description = "사용자 현재 경도 (선택)")
    private Double longitude;

    @Schema(description = "이동 방향 (iOS CLLocation.course, degree, 선택)")
    private Double course;

    @Schema(description = "위치 측정 시각 (ISO-8601, 선택)")
    private OffsetDateTime occurredAt;
}
