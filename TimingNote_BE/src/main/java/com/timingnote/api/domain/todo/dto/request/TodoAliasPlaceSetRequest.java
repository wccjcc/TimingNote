package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "내 장소(별칭)로 Todo 장소 지정 요청")
public class TodoAliasPlaceSetRequest {

    @NotNull
    @Schema(description = "내 장소 ID (user_places.id)", example = "1")
    private Long userPlaceId;
}
