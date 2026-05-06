package com.timingnote.api.domain.notification.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import lombok.Builder;
import lombok.Getter;
import org.springframework.data.domain.Page;

/**
 * 알림 이력 목록 응답 DTO.
 */
@Getter
@Builder
@Schema(description = "알림 이력 목록")
public class NotificationHistoryResponseDto {

    @Schema(description = "알림 이력 목록")
    private List<NotificationHistoryItemResponseDto> content;

    @Schema(description = "전체 개수")
    private long totalElements;

    @Schema(description = "현재 페이지(0-base)")
    private int page;

    @Schema(description = "페이지 크기")
    private int size;

    public static NotificationHistoryResponseDto from(Page<NotificationHistoryItemResponseDto> pageResult) {
        return NotificationHistoryResponseDto.builder()
                .content(pageResult.getContent())
                .totalElements(pageResult.getTotalElements())
                .page(pageResult.getNumber())
                .size(pageResult.getSize())
                .build();
    }
}
