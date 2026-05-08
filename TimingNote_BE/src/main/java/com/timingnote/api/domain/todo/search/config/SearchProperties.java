package com.timingnote.api.domain.todo.search.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "app.search")
public class SearchProperties {

    /** 사용 alias 이름 (애플리케이션 코드 진입점). 실제 인덱스는 {alias}_v1. */
    private String todoIndex = "todos";

    /** false 시 색인 호출은 no-op, 검색 호출은 빈 결과. ES 장애 시 토글용. */
    private boolean enabled = true;

    /** /api/v1/admin/** 엔드포인트 보호용 X-Admin-Secret 헤더 값. */
    private String adminSecret;

    /** 실제 인덱스 이름 (alias가 가리키는 대상). */
    public String physicalIndexName() {
        return todoIndex + "_v1";
    }
}
