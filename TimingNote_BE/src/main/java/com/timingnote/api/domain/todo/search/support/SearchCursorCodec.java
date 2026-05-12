package com.timingnote.api.domain.todo.search.support;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * 검색 페이지네이션 커서 인코딩.
 *
 * <p>현재는 단순 page 번호를 base64 인코딩한다(불투명 토큰).
 * 향후 search_after로 교체 시 외부 API 호환성 유지를 위해 cursor 토큰 형식만 변경하면 됨 — FE는 토큰만 전달.
 */
public final class SearchCursorCodec {

    private static final String PREFIX = "p:";

    private SearchCursorCodec() {}

    public static String encodePage(int page) {
        return Base64.getEncoder().encodeToString((PREFIX + page).getBytes(StandardCharsets.UTF_8));
    }

    public static int decodePage(String cursor) {
        if (cursor == null || cursor.isBlank()) return 0;
        try {
            String decoded = new String(Base64.getDecoder().decode(cursor), StandardCharsets.UTF_8);
            if (!decoded.startsWith(PREFIX)) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR);
            }
            int page = Integer.parseInt(decoded.substring(PREFIX.length()));
            return Math.max(0, page);
        } catch (BusinessException be) {
            throw be;
        } catch (Exception e) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
    }
}
