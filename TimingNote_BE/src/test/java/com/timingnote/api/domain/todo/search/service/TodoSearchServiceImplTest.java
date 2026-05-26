package com.timingnote.api.domain.todo.search.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.todo.search.config.SearchProperties;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import com.timingnote.api.domain.todo.search.dto.TodoSearchRequest;
import com.timingnote.api.domain.todo.search.dto.TodoSearchResponse;
import com.timingnote.api.domain.todo.search.support.SearchCursorCodec;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.client.elc.NativeQuery;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.SearchHit;
import org.springframework.data.elasticsearch.core.SearchHits;
import org.springframework.data.elasticsearch.core.mapping.IndexCoordinates;

@ExtendWith(MockitoExtension.class)
class TodoSearchServiceImplTest {

    @Mock
    private ElasticsearchOperations elasticsearchOperations;

    @Mock
    private SearchHits<TodoSearchDocument> searchHits;

    @Mock
    private SearchHit<TodoSearchDocument> searchHit;

    private SearchProperties searchProperties;
    private TodoSearchServiceImpl searchService;

    @BeforeEach
    void setUp() {
        searchProperties = new SearchProperties();
        searchProperties.setTodoIndex("todos-test");
        searchService = new TodoSearchServiceImpl(elasticsearchOperations, searchProperties);
    }

    @Test
    void search_returnsEmptyResponse_when_searchIsDisabled() {
        searchProperties.setEnabled(false);

        TodoSearchResponse response = searchService.search(1L, request("약국", null, null));

        assertThat(response.getItems()).isEmpty();
        assertThat(response.getNextCursor()).isNull();
        assertThat(response.getTotal()).isZero();
        verify(elasticsearchOperations, never()).search(any(NativeQuery.class), eq(TodoSearchDocument.class), any(IndexCoordinates.class));
    }

    @Test
    void search_mapsHitAndCreatesNextCursor_when_moreResultsExist() {
        TodoSearchDocument document = TodoSearchDocument.builder()
                .id("100")
                .content("약국에서 감기약 사기")
                .placeLabel("약국")
                .todoType("GENERIC")
                .status("ACTIVE")
                .category("HEALTH")
                .build();
        when(searchHit.getContent()).thenReturn(document);
        when(searchHit.getHighlightFields()).thenReturn(Map.of("content", List.of("<em>약국</em>에서 감기약 사기")));
        when(searchHits.getSearchHits()).thenReturn(List.of(searchHit));
        when(searchHits.getTotalHits()).thenReturn(2L);
        when(elasticsearchOperations.search(any(NativeQuery.class), eq(TodoSearchDocument.class), any(IndexCoordinates.class)))
                .thenReturn(searchHits);

        TodoSearchResponse response = searchService.search(1L, request("약국", null, 1));

        assertThat(response.getTotal()).isEqualTo(2L);
        assertThat(response.getNextCursor()).isEqualTo(SearchCursorCodec.encodePage(1));
        assertThat(response.getItems()).hasSize(1);
        assertThat(response.getItems().get(0).getId()).isEqualTo(100L);
        assertThat(response.getItems().get(0).getContent()).isEqualTo("약국에서 감기약 사기");
        assertThat(response.getItems().get(0).getHighlights())
                .containsEntry("content", List.of("<em>약국</em>에서 감기약 사기"));
        assertThat(response.getItems().get(0).getResolvedPlaceLabel()).isEqualTo("약국");
    }

    @Test
    void search_clampsPageSizeToMax() {
        when(searchHits.getSearchHits()).thenReturn(List.of());
        when(searchHits.getTotalHits()).thenReturn(0L);
        when(elasticsearchOperations.search(any(NativeQuery.class), eq(TodoSearchDocument.class), any(IndexCoordinates.class)))
                .thenReturn(searchHits);
        ArgumentCaptor<NativeQuery> queryCaptor = ArgumentCaptor.forClass(NativeQuery.class);

        searchService.search(1L, request("약국", null, 100));

        verify(elasticsearchOperations).search(queryCaptor.capture(), eq(TodoSearchDocument.class), any(IndexCoordinates.class));
        Pageable pageable = queryCaptor.getValue().getPageable();
        assertThat(pageable.getPageNumber()).isZero();
        assertThat(pageable.getPageSize()).isEqualTo(50);
    }

    @Test
    void search_usesCursorPage_when_cursorIsProvided() {
        when(searchHits.getSearchHits()).thenReturn(List.of());
        when(searchHits.getTotalHits()).thenReturn(0L);
        when(elasticsearchOperations.search(any(NativeQuery.class), eq(TodoSearchDocument.class), any(IndexCoordinates.class)))
                .thenReturn(searchHits);
        ArgumentCaptor<NativeQuery> queryCaptor = ArgumentCaptor.forClass(NativeQuery.class);

        searchService.search(1L, request("약국", SearchCursorCodec.encodePage(2), 10));

        verify(elasticsearchOperations).search(queryCaptor.capture(), eq(TodoSearchDocument.class), any(IndexCoordinates.class));
        Pageable pageable = queryCaptor.getValue().getPageable();
        assertThat(pageable.getPageNumber()).isEqualTo(2);
        assertThat(pageable.getPageSize()).isEqualTo(10);
    }

    @Test
    void search_returnsEmptyResponse_when_elasticsearchFails() {
        when(elasticsearchOperations.search(any(NativeQuery.class), eq(TodoSearchDocument.class), any(IndexCoordinates.class)))
                .thenThrow(new IllegalStateException("elasticsearch down"));

        TodoSearchResponse response = searchService.search(1L, request("약국", null, null));

        assertThat(response.getItems()).isEmpty();
        assertThat(response.getNextCursor()).isNull();
        assertThat(response.getTotal()).isZero();
    }

    private TodoSearchRequest request(String query, String cursor, Integer size) {
        return TodoSearchRequest.builder()
                .q(query)
                .cursor(cursor)
                .size(size)
                .build();
    }
}
