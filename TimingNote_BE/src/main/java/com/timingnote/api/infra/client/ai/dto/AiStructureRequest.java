package com.timingnote.api.infra.client.ai.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.Collections;
import java.util.List;

@Getter
@Builder
public class AiStructureRequest {
    private Long todoId;
    private String inputType;      // TEXT | VOICE | IMAGE | LINK
    private String originalText;
    @Builder.Default
    private List<UserPlaceAlias> userPlaceAliases = Collections.emptyList();
}
