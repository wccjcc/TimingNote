package com.timingnote.api.common.exception;

import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public enum ErrorCode {
    // COMMON
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "COMMON-400-1", "입력값이 올바르지 않습니다."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "COMMON-401-1", "인증이 필요합니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "COMMON-403-1", "해당 요청에 대한 권한이 없습니다."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "COMMON-404-1", "요청한 리소스를 찾을 수 없습니다."),

    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "COMMON-500-1", "예상치 못한 서버 오류가 발생하였습니다."),
    MISSING_REQUEST_HEADER(HttpStatus.BAD_REQUEST, "COMMON-400-2", "필수 요청 헤더가 누락되었습니다."),

    //USER
    UUID_CONFLICT(HttpStatus.CONFLICT, "COMMON-409-1", "이미 존재하는 uuid입니다."),

    // GEOFENCE
    INVALID_GEOFENCE_RECALCULATE_REQUEST(HttpStatus.BAD_REQUEST, "GEOFENCE-400-1", "Geofence 재계산 요청 파라미터가 유효하지 않습니다."),
    GEOFENCE_RECALCULATE_ENQUEUE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "GEOFENCE-500-1", "Geofence 재계산 요청 적재(outbox enqueue)에 실패했습니다.");

    private final HttpStatus status;
    private final String code;
    private final String message;
}
