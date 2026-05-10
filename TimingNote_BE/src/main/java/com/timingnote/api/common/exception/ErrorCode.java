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
    USER_NOT_FOUND(HttpStatus.NOT_FOUND, "USER-404-1", "사용자를 찾을 수 없어요."),
    USER_PLACE_NOT_FOUND(HttpStatus.NOT_FOUND, "USER-404-2", "등록된 장소를 찾을 수 없어요."),
    USER_PLACE_NAME_DUPLICATED(HttpStatus.CONFLICT, "USER-409-1", "이미 사용 중인 장소 별칭이에요."),
    //SETTING
    SETTINGS_NOT_FOUND(HttpStatus.NOT_FOUND,"SETTING-404-1","사용자 설정이 존재하지 않습니다."),

    // GEOFENCE
    INVALID_GEOFENCE_RECALCULATE_REQUEST(HttpStatus.BAD_REQUEST, "GEOFENCE-400-1", "Geofence 재계산 요청 파라미터가 유효하지 않습니다."),
    GEOFENCE_RECALCULATE_ENQUEUE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "GEOFENCE-500-1", "Geofence 재계산 요청 적재(outbox enqueue)에 실패했습니다."),

    // TODO
    TODO_NOT_FOUND(HttpStatus.NOT_FOUND, "TODO-404-1", "할 일을 찾을 수 없어요."),
    TODO_FORBIDDEN(HttpStatus.FORBIDDEN, "TODO-403-1", "본인의 할 일만 수정할 수 있어요."),
    TODO_INVALID_TIME_FORMAT(HttpStatus.UNPROCESSABLE_ENTITY, "TODO-422-1", "입력한 시간 형식이 올바르지 않아요."),
    TODO_CONTENT_REQUIRED(HttpStatus.BAD_REQUEST, "TODO-400-1", "메모 내용을 입력해주세요."),

    // PLACE
    PLACE_NOT_FOUND(HttpStatus.NOT_FOUND, "PLACE-404-1", "장소를 찾을 수 없어요."),

    // AI
    AI_STRUCTURE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "AI-500-1", "AI 분석에 실패했어요. 잠시 후 다시 시도해주세요.");

    private final HttpStatus status;
    private final String code;
    private final String message;
}
