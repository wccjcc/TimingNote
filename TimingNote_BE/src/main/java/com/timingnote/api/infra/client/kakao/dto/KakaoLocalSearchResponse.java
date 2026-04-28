package com.timingnote.api.infra.client.kakao.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@NoArgsConstructor
public class KakaoLocalSearchResponse {

    private List<KakaoDocument> documents;
}
