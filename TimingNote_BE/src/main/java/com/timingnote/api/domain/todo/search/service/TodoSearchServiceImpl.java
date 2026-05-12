package com.timingnote.api.domain.todo.search.service;

import co.elastic.clients.elasticsearch._types.FieldValue;
import co.elastic.clients.elasticsearch._types.query_dsl.Query;
import co.elastic.clients.elasticsearch._types.query_dsl.TextQueryType;
import com.timingnote.api.domain.todo.search.config.SearchProperties;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import com.timingnote.api.domain.todo.search.dto.TodoSearchItemResponse;
import com.timingnote.api.domain.todo.search.dto.TodoSearchRequest;
import com.timingnote.api.domain.todo.search.dto.TodoSearchResponse;
import com.timingnote.api.domain.todo.search.support.SearchCursorCodec;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.elasticsearch.client.elc.NativeQuery;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.SearchHits;
import org.springframework.data.elasticsearch.core.mapping.IndexCoordinates;
import org.springframework.data.elasticsearch.core.query.HighlightQuery;
import org.springframework.data.elasticsearch.core.query.highlight.Highlight;
import org.springframework.data.elasticsearch.core.query.highlight.HighlightField;
import org.springframework.data.elasticsearch.core.query.highlight.HighlightFieldParameters;
import org.springframework.data.elasticsearch.core.query.highlight.HighlightParameters;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * 할 일 검색 본체.
 *
 * <p>쿼리 구성:
 * - must: multi_match(content^4, placeLabel^2, placeName) — best_fields, Nori 형태소 분석 적용
 * - filter: userId term — **의무 필터**
 * - filter (옵션): status / category / todoType
 * - must_not: status=DELETED — 소프트 삭제 항목 항상 제외
 *
 * <p>정렬: [_score desc, createdAt desc, id desc] (안정적 tiebreaker).
 * 페이지네이션: page 기반(SearchCursorCodec). 향후 search_after로 교체 가능.
 *
 * <p>ES 장애 시 graceful degradation — 빈 응답을 반환하고 ERROR 로그.
 * {@code app.search.enabled=false} 시에도 빈 응답.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TodoSearchServiceImpl implements TodoSearchService {

    private static final int DEFAULT_SIZE = 20;
    private static final int MAX_SIZE = 50;

    private final ElasticsearchOperations elasticsearchOperations;
    private final SearchProperties searchProperties;

    @Override
    public TodoSearchResponse search(Long userId, TodoSearchRequest request) {
        if (!searchProperties.isEnabled()) {
            log.debug("[Search] disabled — return empty");
            return TodoSearchResponse.empty();
        }

        int size = clamp(request.getSize() != null ? request.getSize() : DEFAULT_SIZE, 1, MAX_SIZE);
        int page = SearchCursorCodec.decodePage(request.getCursor());

        try {
            NativeQuery query = buildQuery(userId, request, page, size);
            SearchHits<TodoSearchDocument> hits = elasticsearchOperations.search(
                    query, TodoSearchDocument.class,
                    IndexCoordinates.of(searchProperties.getTodoIndex()));

            List<TodoSearchItemResponse> items = hits.getSearchHits().stream()
                    .map(TodoSearchItemResponse::from)
                    .toList();

            long total = hits.getTotalHits();
            int consumedSoFar = (page * size) + items.size();
            String nextCursor = consumedSoFar < total ? SearchCursorCodec.encodePage(page + 1) : null;

            return TodoSearchResponse.builder()
                    .items(items)
                    .nextCursor(nextCursor)
                    .total(total)
                    .build();
        } catch (Exception e) {
            log.error("[Search] 검색 실패 — userId={} q='{}' cause={}",
                    userId, request.getQ(), e.getMessage(), e);
            return TodoSearchResponse.empty();
        }
    }

    private NativeQuery buildQuery(Long userId, TodoSearchRequest req, int page, int size) {
        Query mustClause = Query.of(q -> q.multiMatch(mm -> mm
                .query(req.getQ())
                .fields("content^4", "placeLabel^2", "placeName")
                .type(TextQueryType.BestFields)
        ));

        // status는 미입력 시 기본 ACTIVE — todo 앱 검색의 일반적 UX (완료 항목은 FE 토글로 명시 요청).
        // DELETED는 mustNot으로 항상 제외(이중 안전망).
        String effectiveStatus = StringUtils.hasText(req.getStatus()) ? req.getStatus() : "ACTIVE";

        List<Query> filters = new ArrayList<>();
        filters.add(termQuery("userId", String.valueOf(userId)));
        filters.add(termQuery("status", effectiveStatus));
        if (StringUtils.hasText(req.getCategory())) {
            filters.add(termQuery("category", req.getCategory()));
        }
        if (StringUtils.hasText(req.getTodoType())) {
            filters.add(termQuery("todoType", req.getTodoType()));
        }

        Query mustNotDeleted = termQuery("status", "DELETED");

        Query boolQuery = Query.of(q -> q.bool(b -> b
                .must(mustClause)
                .filter(filters)
                .mustNot(mustNotDeleted)
        ));

        // 정렬에 _id를 포함하면 ES 8.x에서 fielddata 활성화 필요 → all shards failed.
        // _score + createdAt만으로 충분히 안정적(createdAt은 마이크로초 단위 timestamp).
        return NativeQuery.builder()
                .withQuery(boolQuery)
                .withSort(Sort.by(
                        Sort.Order.desc("_score"),
                        Sort.Order.desc("createdAt")))
                .withPageable(PageRequest.of(page, size))
                .withTrackTotalHits(true)
                .withHighlightQuery(buildHighlight())
                .build();
    }

    private static Query termQuery(String field, String value) {
        return Query.of(q -> q.term(t -> t.field(field).value(FieldValue.of(value))));
    }

    private HighlightQuery buildHighlight() {
        HighlightFieldParameters fieldParams = HighlightFieldParameters.builder()
                .withFragmentSize(150)
                .withNumberOfFragments(2)
                .build();

        List<HighlightField> fields = List.of(
                new HighlightField("content", fieldParams),
                new HighlightField("placeLabel", fieldParams),
                new HighlightField("placeName", fieldParams)
        );

        HighlightParameters globalParams = HighlightParameters.builder()
                .withPreTags("<em>")
                .withPostTags("</em>")
                .build();

        return new HighlightQuery(new Highlight(globalParams, fields), TodoSearchDocument.class);
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
