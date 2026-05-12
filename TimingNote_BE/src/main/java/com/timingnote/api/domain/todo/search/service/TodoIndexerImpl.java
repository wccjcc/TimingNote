package com.timingnote.api.domain.todo.search.service;

import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.search.config.SearchProperties;
import com.timingnote.api.domain.todo.search.document.TodoSearchDocument;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import reactor.core.scheduler.Schedulers;

import java.util.List;

/**
 * 색인 호출 본체. afterCommit에서 boundedElastic 스케줄링된 후 호출되며,
 * DB 조회는 외부 빈({@link TodoDocumentAssembler})에 위임 후 ES upsert만 담당.
 *
 * <p>호출 진입점이 트랜잭션 없는 boundedElastic 스레드이므로
 * 본 빈은 의도적으로 @Transactional을 두지 않는다 — 재시도 sleep 동안 DB 커넥션 점유 방지.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TodoIndexerImpl implements TodoIndexer {

    private static final long[] BACKOFF_MS = {1000L, 3000L, 9000L};

    private final TodoRepository todoRepository;
    private final TodoDocumentAssembler assembler;
    private final ElasticsearchOperations elasticsearchOperations;
    private final SearchProperties searchProperties;

    @Override
    public void scheduleAfterCommit(Long todoId) {
        if (!searchProperties.isEnabled()) {
            return;
        }
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    Schedulers.boundedElastic().schedule(() -> safeIndex(todoId));
                }
            });
        } else {
            // 트랜잭션 컨텍스트 밖 (boundedElastic 등) — 즉시 비동기 실행
            Schedulers.boundedElastic().schedule(() -> safeIndex(todoId));
        }
    }

    private void safeIndex(Long todoId) {
        try {
            indexNow(todoId);
        } catch (Exception e) {
            log.warn("[Search] async 색인 실패 todoId={} cause={}", todoId, e.getMessage());
        }
    }

    @Override
    public void indexNow(Long todoId) {
        if (!searchProperties.isEnabled()) {
            return;
        }
        TodoSearchDocument doc = assembler.assemble(todoId).orElse(null);
        if (doc == null) {
            log.warn("[Search] indexNow — todo not found, skip: id={}", todoId);
            return;
        }
        upsertWithRetry(doc);
    }

    @Override
    public int bulkReindex(Long fromId, int batchSize, Long userIdFilter) {
        if (!searchProperties.isEnabled()) {
            log.info("[Search] bulkReindex — search disabled, skip");
            return 0;
        }

        long cursor = fromId == null ? 0L : fromId;
        int total = 0;
        while (true) {
            List<Todo> page = todoRepository.findForReindex(
                    cursor, userIdFilter, PageRequest.of(0, batchSize));
            if (page.isEmpty()) break;

            List<TodoSearchDocument> docs = assembler.assembleBatch(page);
            elasticsearchOperations.save(docs);
            total += docs.size();
            log.info("[Search] bulkReindex batch indexed — count={} fromId={} userIdFilter={}",
                    docs.size(), cursor, userIdFilter);

            cursor = page.get(page.size() - 1).getId();
            if (page.size() < batchSize) break;
        }
        log.info("[Search] bulkReindex done — total={} userIdFilter={}", total, userIdFilter);
        return total;
    }

    private void upsertWithRetry(TodoSearchDocument doc) {
        Exception lastEx = null;
        for (int attempt = 0; attempt <= BACKOFF_MS.length; attempt++) {
            try {
                elasticsearchOperations.save(doc);
                return;
            } catch (Exception e) {
                lastEx = e;
                if (attempt < BACKOFF_MS.length) {
                    long wait = BACKOFF_MS[attempt];
                    log.warn("[Search] 색인 재시도 attempt={} wait={}ms id={} cause={}",
                            attempt + 1, wait, doc.getId(), e.getMessage());
                    try {
                        Thread.sleep(wait);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        return;
                    }
                }
            }
        }
        log.error("[Search] 색인 최종 실패 — id={} cause={}",
                doc.getId(), lastEx != null ? lastEx.getMessage() : "unknown");
    }
}
