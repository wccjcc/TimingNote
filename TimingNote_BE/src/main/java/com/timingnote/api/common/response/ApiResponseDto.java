package com.timingnote.api.common.response;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponseDto<T> {
    private final boolean success;
    private final T data;
    private final String msg;
    private final ErrorInfo error;

    @Getter
    @AllArgsConstructor
    public static class ErrorInfo {
        private final String code;
        private final String message;
    }

    // --- 성공 (Success) ---

    // 데이터만 응답
    public static <T> ApiResponseDto<T> success(T data) {
        return new ApiResponseDto<>(true, data, null, null);
    }

    // 데이터 + 메시지 응답
    public static <T> ApiResponseDto<T> success(T data, String msg) {
        return new ApiResponseDto<>(true, data, msg, null);
    }

    // 메시지만 응답
    public static <T> ApiResponseDto<T> successMsg(String msg) {
        return new ApiResponseDto<>(true, null, msg, null);
    }

    // --- 실패 (Error) ---

    // BusinessException 전용 응답
    public static ApiResponseDto<Object> error(BusinessException ex) {
        ErrorCode errorCode = ex.getErrorCode();
        String message = (ex.getMessage() != null && !ex.getMessage().isBlank())
                ? ex.getMessage()
                : errorCode.getMessage();
        
        return new ApiResponseDto<>(
                false, 
                ex.getData(), 
                null, 
                new ErrorInfo(errorCode.getCode(), message)
        );
    }

    // 일반 ErrorCode 전용 응답
    public static ApiResponseDto<Void> error(ErrorCode errorCode) {
        return new ApiResponseDto<>(
                false, 
                null, 
                null, 
                new ErrorInfo(errorCode.getCode(), errorCode.getMessage())
        );
    }

    // 에러 코드 + 커스텀 메시지 응답
    public static ApiResponseDto<Void> error(ErrorCode errorCode, String message) {
        return new ApiResponseDto<>(
                false, 
                null, 
                null, 
                new ErrorInfo(errorCode.getCode(), message)
        );
    }
}
