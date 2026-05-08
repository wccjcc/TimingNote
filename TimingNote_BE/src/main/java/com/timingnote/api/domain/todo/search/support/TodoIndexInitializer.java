package com.timingnote.api.domain.todo.search.support;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.timingnote.api.domain.todo.search.config.SearchProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.springframework.data.elasticsearch.core.document.Document;
import org.springframework.data.elasticsearch.core.index.AliasAction;
import org.springframework.data.elasticsearch.core.index.AliasActionParameters;
import org.springframework.data.elasticsearch.core.index.AliasActions;
import org.springframework.data.elasticsearch.core.mapping.IndexCoordinates;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * 애플리케이션 시작 시 ES 인덱스/매핑/alias를 멱등하게 생성한다.
 *
 * <p>설계 의도:
 * - 물리 인덱스 이름은 {@code todos_v1} (alias = {@code todos}).
 * - 매핑 변경 시 {@code todos_v2} 새로 만들고 reindex → alias swap 무중단 전환 가능 구조.
 * - 검색/색인 코드는 alias({@link SearchProperties#getTodoIndex()})만 참조하므로 물리 인덱스 교체에 영향 없음.
 *
 * <p>{@code app.search.enabled=false}면 skip — ES 미부팅 환경에서도 앱 자체는 살아있도록.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TodoIndexInitializer {

    private static final String SETTINGS_PATH = "elasticsearch/todos-settings.json";
    private static final String MAPPINGS_PATH = "elasticsearch/todos-mappings.json";

    private final ElasticsearchOperations elasticsearchOperations;
    private final SearchProperties searchProperties;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @EventListener(ApplicationReadyEvent.class)
    public void initializeIndex() {
        if (!searchProperties.isEnabled()) {
            log.info("[Search] app.search.enabled=false → 인덱스 초기화 스킵");
            return;
        }

        String physical = searchProperties.physicalIndexName();
        String alias = searchProperties.getTodoIndex();

        try {
            createIndexIfMissing(physical);
            attachAliasIfMissing(physical, alias);
        } catch (Exception e) {
            log.error("[Search] 인덱스 초기화 실패 — physical={} alias={} cause={}",
                    physical, alias, e.getMessage(), e);
        }
    }

    private void createIndexIfMissing(String physical) throws Exception {
        IndexOperations idxOps = elasticsearchOperations.indexOps(IndexCoordinates.of(physical));
        if (idxOps.exists()) {
            log.debug("[Search] 인덱스 이미 존재 — skip create: {}", physical);
            return;
        }

        Map<String, Object> settings = readJsonAsMap(SETTINGS_PATH);
        Document mapping = Document.parse(readResource(MAPPINGS_PATH));

        idxOps.create(settings, mapping);
        log.info("[Search] 인덱스 생성 완료: {}", physical);
    }

    private void attachAliasIfMissing(String physical, String alias) {
        IndexOperations aliasOps = elasticsearchOperations.indexOps(IndexCoordinates.of(alias));
        boolean aliasResolves = aliasOps.exists();
        if (aliasResolves) {
            log.debug("[Search] alias 이미 존재 — skip attach: {}", alias);
            return;
        }

        AliasActions actions = new AliasActions(
                new AliasAction.Add(
                        AliasActionParameters.builder()
                                .withIndices(physical)
                                .withAliases(alias)
                                .build()
                )
        );
        elasticsearchOperations.indexOps(IndexCoordinates.of(physical)).alias(actions);
        log.info("[Search] alias 부착 완료: {} → {}", alias, physical);
    }

    private String readResource(String path) throws Exception {
        return new ClassPathResource(path).getContentAsString(StandardCharsets.UTF_8);
    }

    private Map<String, Object> readJsonAsMap(String path) throws Exception {
        return objectMapper.readValue(readResource(path), new TypeReference<Map<String, Object>>() {});
    }
}
