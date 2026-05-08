package com.timingnote.api.domain.todo.search.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.todo.search.config.SearchProperties;
import com.timingnote.api.domain.todo.search.dto.TodoReindexRequest;
import com.timingnote.api.domain.todo.search.service.TodoIndexer;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 검색 인덱스 백필/재색인용 관리자 엔드포인트.
 *
 * <p>X-Device-Secret 인증을 우회하므로(WebMvcConfig에서 /api/v1/admin/** 제외),
 * 자체적으로 X-Admin-Secret 헤더로 보호한다.
 * 운영자가 배포 직후 1회 호출 + 부분 재색인 복구용으로 사용.
 */
@Slf4j
@Tag(name = "Admin: Todo Search Reindex")
@RestController
@RequestMapping("/api/v1/admin/todos")
@RequiredArgsConstructor
public class TodoReindexAdminController {

    public static final String ADMIN_SECRET_HEADER = "X-Admin-Secret";

    private final TodoIndexer todoIndexer;
    private final SearchProperties searchProperties;

    @Operation(summary = "Todo 검색 인덱스 재색인",
            description = "지정한 범위의 todo를 ES에 일괄 upsert. fromId 미지정 시 처음부터, userId 미지정 시 전체 사용자.")
    @PostMapping("/reindex")
    public ResponseEntity<Map<String, Object>> reindex(
            @RequestHeader(ADMIN_SECRET_HEADER) String adminSecret,
            @Valid @RequestBody(required = false) TodoReindexRequest request) {

        verifyAdminSecret(adminSecret);

        TodoReindexRequest req = request != null ? request : new TodoReindexRequest();
        int batchSize = req.getBatchSize() != null ? req.getBatchSize() : 500;

        log.info("[Search/Admin] reindex 시작 — fromId={} userId={} batchSize={}",
                req.getFromId(), req.getUserId(), batchSize);

        int indexed = todoIndexer.bulkReindex(req.getFromId(), batchSize, req.getUserId());

        return ResponseEntity.ok(Map.of(
                "indexed", indexed,
                "fromId", req.getFromId() != null ? req.getFromId() : 0,
                "userId", req.getUserId() != null ? req.getUserId() : 0,
                "batchSize", batchSize
        ));
    }

    private void verifyAdminSecret(String provided) {
        String expected = searchProperties.getAdminSecret();
        if (!StringUtils.hasText(expected) || !expected.equals(provided)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
    }
}
