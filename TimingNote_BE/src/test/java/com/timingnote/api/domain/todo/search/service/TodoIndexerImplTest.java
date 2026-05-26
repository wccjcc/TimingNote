package com.timingnote.api.domain.todo.search.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.search.config.SearchProperties;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;

@ExtendWith(MockitoExtension.class)
class TodoIndexerImplTest {

    @Mock
    private TodoRepository todoRepository;

    @Mock
    private TodoDocumentAssembler assembler;

    @Mock
    private ElasticsearchOperations elasticsearchOperations;

    private SearchProperties searchProperties;
    private TodoIndexerImpl indexer;

    @BeforeEach
    void setUp() {
        searchProperties = new SearchProperties();
        indexer = new TodoIndexerImpl(todoRepository, assembler, elasticsearchOperations, searchProperties);
    }

    @Test
    void indexNow_skipsAllWork_when_searchIsDisabled() {
        searchProperties.setEnabled(false);

        indexer.indexNow(1L);

        verifyNoInteractions(assembler, elasticsearchOperations);
    }

    @Test
    void indexNow_skipsSave_when_todoDocumentDoesNotExist() {
        when(assembler.assemble(1L)).thenReturn(Optional.empty());

        indexer.indexNow(1L);

        verify(assembler).assemble(1L);
        verify(elasticsearchOperations, never()).save(any(TodoSearchDocument.class));
    }

    @Test
    void indexNow_savesAssembledDocument() {
        TodoSearchDocument document = document(1L);
        when(assembler.assemble(1L)).thenReturn(Optional.of(document));

        indexer.indexNow(1L);

        verify(elasticsearchOperations).save(document);
    }

    @Test
    void bulkReindex_returnsZero_when_searchIsDisabled() {
        searchProperties.setEnabled(false);

        int indexedCount = indexer.bulkReindex(null, 2, null);

        assertThat(indexedCount).isZero();
        verifyNoInteractions(todoRepository, assembler, elasticsearchOperations);
    }

    @Test
    void bulkReindex_indexesPagesUntilLastPage() {
        Todo firstTodo = todo(1L);
        Todo secondTodo = todo(2L);
        Todo thirdTodo = todo(3L);
        TodoSearchDocument firstDocument = document(1L);
        TodoSearchDocument secondDocument = document(2L);
        TodoSearchDocument thirdDocument = document(3L);
        when(todoRepository.findForReindex(eq(0L), eq(99L), any(Pageable.class)))
                .thenReturn(List.of(firstTodo, secondTodo));
        when(todoRepository.findForReindex(eq(2L), eq(99L), any(Pageable.class)))
                .thenReturn(List.of(thirdTodo));
        when(assembler.assembleBatch(List.of(firstTodo, secondTodo)))
                .thenReturn(List.of(firstDocument, secondDocument));
        when(assembler.assembleBatch(List.of(thirdTodo)))
                .thenReturn(List.of(thirdDocument));

        int indexedCount = indexer.bulkReindex(null, 2, 99L);

        assertThat(indexedCount).isEqualTo(3);
        verify(elasticsearchOperations).save(List.of(firstDocument, secondDocument));
        verify(elasticsearchOperations).save(List.of(thirdDocument));
    }

    @Test
    void bulkReindex_usesProvidedFromId() {
        when(todoRepository.findForReindex(eq(50L), isNull(), any(Pageable.class)))
                .thenReturn(List.of());

        int indexedCount = indexer.bulkReindex(50L, 10, null);

        assertThat(indexedCount).isZero();
        verify(todoRepository).findForReindex(eq(50L), isNull(), any(Pageable.class));
    }

    private Todo todo(Long id) {
        return Todo.builder()
                .id(id)
                .userId(10L)
                .category("HEALTH")
                .inputType("TEXT")
                .todoType("GENERIC")
                .status("ACTIVE")
                .structureStatus("READY")
                .content("약국 들르기")
                .alertEnabled(true)
                .build();
    }

    private TodoSearchDocument document(Long id) {
        return TodoSearchDocument.builder()
                .id(String.valueOf(id))
                .userId("10")
                .content("약국 들르기")
                .status("ACTIVE")
                .todoType("GENERIC")
                .structureStatus("READY")
                .build();
    }
}
