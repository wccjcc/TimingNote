package com.timingnote.api.domain.user.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "내 장소 별칭 수정 요청")
public class UserPlaceUpdateRequest {

    @NotBlank
    @Schema(description = "변경할 별칭", example = "본가")
    private String aliasName;
}
