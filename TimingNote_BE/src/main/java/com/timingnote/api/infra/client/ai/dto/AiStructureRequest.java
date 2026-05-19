package com.timingnote.api.infra.client.ai.dto;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class AiStructureRequest {
    private Long todoId;
    private String inputType;      // TEXT | VOICE | IMAGE | LINK
    private String originalText;
}
