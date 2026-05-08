package com.timingnote.api.domain.todo.search.service;

/**
 * 모든 Todo 색인 진입점. 호출자는 "이 todoId가 변경됐다"만 알리고,
 * 구현체가 DB에서 latest snapshot을 읽어 ES upsert.
 */
public interface TodoIndexer {

    /**
     * Todo CRUD 트랜잭션 안에서 호출. 트랜잭션 커밋 직후 boundedElastic 스레드에서 색인.
     * 트랜잭션 밖에서 호출되면 즉시 비동기 색인.
     *
     * <p>실패 시 내부 백오프 재시도. 색인 실패가 호출자 비즈니스 흐름에 영향 주지 않음.
     * 기존 "Todo 내부 이벤트 = afterCommit + boundedElastic" 패턴을 캡슐화한다.
     */
    void scheduleAfterCommit(Long todoId);

    /**
     * 단건 동기 색인. 호출자가 이미 비동기 컨텍스트(boundedElastic)에 있을 때 사용.
     *
     * <p>실패 시 내부 백오프 재시도(1·3·9초). 모두 실패해도 예외 던지지 않고 ERROR 로그만.
     * Todo가 이미 hard-delete됐으면 no-op.
     */
    void indexNow(Long todoId);

    /**
     * Bulk 백필. fromId 이후의 todo를 batchSize만큼씩 ES Bulk API로 upsert.
     * userIdFilter가 있으면 해당 사용자만, 없으면 전체.
     *
     * @return 인덱싱된 도큐먼트 수
     */
    int bulkReindex(Long fromId, int batchSize, Long userIdFilter);
}
