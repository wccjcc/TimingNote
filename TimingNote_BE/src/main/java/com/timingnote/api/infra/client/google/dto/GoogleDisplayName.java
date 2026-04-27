package com.timingnote.api.infra.client.google.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class GoogleDisplayName {

    private String text;
    private String languageCode;
}
