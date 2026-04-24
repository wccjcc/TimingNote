package com.timingnote.api.domain.todo.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "Todo 생성 요청")
public class TodoCreateRequest {

    @NotBlank
    @Size(max = 2000)
    @Schema(description = "메모 원문", example = "내일 오후 3시에 홈플러스 서면점 가서 우유 사기")
    private String content;

    @NotBlank
    @Pattern(regexp = "TEXT|VOICE|IMAGE|LINK")
    @Schema(description = "입력 유형", allowableValues = {"TEXT", "VOICE", "IMAGE", "LINK"}, example = "TEXT")
    private String inputType;
}
