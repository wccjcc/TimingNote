package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "할 일 상태 변경 요청")
public class TodoStatusUpdateRequest {

    @NotBlank
    @Pattern(regexp = "ACTIVE|DONE", message = "status는 ACTIVE 또는 DONE이어야 합니다")
    @Schema(description = "변경할 상태", allowableValues = {"ACTIVE", "DONE"})
    private String status;
}
