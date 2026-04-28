package com.timingnote.api.infra.client.google.dto;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class GoogleTextSearchRequest {

    private String textQuery;
}
