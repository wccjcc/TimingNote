package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "알림 설정 변경 요청")
public class TodoAlertUpdateRequest {

    @NotNull
    @Schema(description = "알림 활성화 여부")
    private Boolean alertEnabled;
}
