package com.timingnote.api.common.exception;

import com.timingnote.api.common.response.ApiResponseDto;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.http.MockHttpInputMessage;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.context.request.async.AsyncRequestNotUsableException;
import org.springframework.web.context.request.async.AsyncRequestTimeoutException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import jakarta.validation.ConstraintViolationException;
import java.lang.reflect.Method;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    @DisplayName("비즈니스 예외 발생 시 에러 코드와 상태 코드가 일치해야 한다")
    void handleBusinessExceptionUsesErrorCodeStatusAndBody() {
        // given
        BusinessException exception = new BusinessException("not mine", ErrorCode.FORBIDDEN);

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleBusinessException(exception);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().isSuccess()).isFalse();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.FORBIDDEN.getCode());
        assertThat(response.getBody().getError().getMessage()).isEqualTo("not mine");
    }

    @Test
    @DisplayName("유효성 검증 실패 시 첫 번째 필드 에러 메시지를 반환해야 한다")
    void handleValidationExceptionUsesFirstFieldErrorMessage() throws NoSuchMethodException {
        // given
        MethodArgumentNotValidException exception = validationExceptionWithFieldError("content is required");

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleValidationException(exception);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.VALIDATION_ERROR.getCode());
        assertThat(response.getBody().getError().getMessage()).isEqualTo("content is required");
    }

    @Test
    @DisplayName("필드 에러가 없는 유효성 검증 실패 시 기본 메시지를 반환해야 한다")
    void handleValidationExceptionFallsBackToDefaultMessageWhenNoFieldErrorExists() throws NoSuchMethodException {
        // given
        MethodArgumentNotValidException exception = validationExceptionWithoutFieldError();

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleValidationException(exception);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getMessage()).isEqualTo(ErrorCode.VALIDATION_ERROR.getMessage());
    }

    @Test
    @DisplayName("타입 불일치 예외 발생 시 유효성 검증 에러를 반환해야 한다")
    void handleTypeMismatchReturnsValidationError() {
        // given
        MethodArgumentTypeMismatchException exception = mock(MethodArgumentTypeMismatchException.class);
        when(exception.getMessage()).thenReturn("type mismatch");

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleTypeMismatch(exception);

        // then
        assertValidationErrorResponse(response);
    }

    @Test
    @DisplayName("제약 조건 위반 예외 발생 시 유효성 검증 에러를 반환해야 한다")
    void handleConstraintViolationReturnsValidationError() {
        // when
        ResponseEntity<ApiResponseDto<?>> response =
                handler.handleConstraintViolation(new ConstraintViolationException("invalid", Set.of()));

        // then
        assertValidationErrorResponse(response);
    }

    @Test
    @DisplayName("HTTP 메시지 읽기 실패 시 유효성 검증 에러를 반환해야 한다")
    void handleNotReadableReturnsValidationError() {
        // when
        ResponseEntity<ApiResponseDto<?>> response =
                handler.handleNotReadable(new HttpMessageNotReadableException(
                        "invalid json", new MockHttpInputMessage(new byte[0])));

        // then
        assertValidationErrorResponse(response);
    }

    @Test
    @DisplayName("필수 요청 헤더 누락 시 관련 에러를 반환해야 한다")
    void handleMissingRequestHeaderReturnsMissingHeaderError() throws NoSuchMethodException {
        // when
        ResponseEntity<ApiResponseDto<?>> response =
                handler.handleMissingRequestHeader(new MissingRequestHeaderException("X-Device-Secret", methodParameter()));

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.MISSING_REQUEST_HEADER.getCode());
    }

    @Test
    @DisplayName("리소스 찾지 못함 예외 발생 시 NOT_FOUND 에러를 반환해야 한다")
    void handleNoResourceFoundExceptionReturnsNotFound() {
        // given
        NoResourceFoundException exception = mock(NoResourceFoundException.class);
        when(exception.getResourcePath()).thenReturn("/missing.png");

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleNoResourceFoundException(exception);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.NOT_FOUND.getCode());
    }

    @Test
    @DisplayName("SSE 요청 중 예외 발생 시 NO_CONTENT를 반환하고 응답 바디는 비어있어야 한다")
    void handleUnhandledExceptionReturnsNoContentForSseRequest() {
        // given
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/geofence/slots/stream");
        request.addHeader("Accept", MediaType.TEXT_EVENT_STREAM_VALUE);

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleUnhandledException(new RuntimeException("boom"), request);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(response.getBody()).isNull();
    }

    @Test
    @DisplayName("일반 요청 중 예외 발생 시 INTERNAL_SERVER_ERROR를 반환해야 한다")
    void handleUnhandledExceptionReturnsInternalServerErrorForNormalRequest() {
        // given
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/todos");

        // when
        ResponseEntity<ApiResponseDto<?>> response = handler.handleUnhandledException(new RuntimeException("boom"), request);

        // then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.INTERNAL_SERVER_ERROR.getCode());
    }

    @Test
    @DisplayName("비동기 요청 관련 예외는 무시되어야 하며 예외를 발생시키지 않아야 한다")
    void asyncRequestExceptionsAreIgnored() {
        assertDoesNotThrow(() -> {
            handler.handleAsyncRequestNotUsableException(mock(AsyncRequestNotUsableException.class));
            handler.handleAsyncRequestTimeoutException(mock(AsyncRequestTimeoutException.class));
        });
    }

    private void assertValidationErrorResponse(ResponseEntity<ApiResponseDto<?>> response) {
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getError().getCode()).isEqualTo(ErrorCode.VALIDATION_ERROR.getCode());
    }

    private MethodArgumentNotValidException validationExceptionWithFieldError(String message) throws NoSuchMethodException {
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Object(), "request");
        bindingResult.addError(new FieldError("request", "content", message));
        return new MethodArgumentNotValidException(methodParameter(), bindingResult);
    }

    private MethodArgumentNotValidException validationExceptionWithoutFieldError() throws NoSuchMethodException {
        return new MethodArgumentNotValidException(methodParameter(), new BeanPropertyBindingResult(new Object(), "request"));
    }

    private MethodParameter methodParameter() throws NoSuchMethodException {
        Method method = GlobalExceptionHandlerTest.class.getDeclaredMethod("validationTarget", String.class);
        return new MethodParameter(method, 0);
    }

    @SuppressWarnings("unused")
    private void validationTarget(String value) {
        // MethodParameter 생성을 위한 리플렉션 타겟 메서드로, 실제 실행되지 않음
    }
}
