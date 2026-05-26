package com.timingnote.api.common.response;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class ApiResponseDtoTest {

    @Test
    void successStoresDataOnly() {
        // when
        ApiResponseDto<String> response = ApiResponseDto.success("ok");

        // then
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getData()).isEqualTo("ok");
        assertThat(response.getMsg()).isNull();
        assertThat(response.getError()).isNull();
    }

    @Test
    void successStoresDataAndMessage() {
        // when
        ApiResponseDto<String> response = ApiResponseDto.success("ok", "created");

        // then
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getData()).isEqualTo("ok");
        assertThat(response.getMsg()).isEqualTo("created");
        assertThat(response.getError()).isNull();
    }

    @Test
    void successMsgStoresMessageOnly() {
        // when
        ApiResponseDto<String> response = ApiResponseDto.successMsg("deleted");

        // then
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getData()).isNull();
        assertThat(response.getMsg()).isEqualTo("deleted");
        assertThat(response.getError()).isNull();
    }

    @Test
    void errorFromBusinessExceptionKeepsDataAndCustomMessage() {
        // given
        Map<String, Object> data = Map.of("field", "content");
        BusinessException exception = new BusinessException("custom validation", ErrorCode.VALIDATION_ERROR, data);

        // when
        ApiResponseDto<Object> response = ApiResponseDto.error(exception);

        // then
        assertThat(response.isSuccess()).isFalse();
        assertThat(response.getData()).isEqualTo(data);
        assertThat(response.getMsg()).isNull();
        assertThat(response.getError().getCode()).isEqualTo(ErrorCode.VALIDATION_ERROR.getCode());
        assertThat(response.getError().getMessage()).isEqualTo("custom validation");
    }

    @Test
    void errorFromBusinessExceptionFallsBackToErrorCodeMessageWhenMessageIsBlank() {
        // given
        BusinessException exception = new BusinessException(" ", ErrorCode.UNAUTHORIZED);

        // when
        ApiResponseDto<Object> response = ApiResponseDto.error(exception);

        // then
        assertThat(response.getError().getCode()).isEqualTo(ErrorCode.UNAUTHORIZED.getCode());
        assertThat(response.getError().getMessage()).isEqualTo(ErrorCode.UNAUTHORIZED.getMessage());
    }

    @Test
    void errorFromErrorCodeUsesDefaultMessage() {
        // when
        ApiResponseDto<Void> response = ApiResponseDto.error(ErrorCode.NOT_FOUND);

        // then
        assertThat(response.isSuccess()).isFalse();
        assertThat(response.getError().getCode()).isEqualTo(ErrorCode.NOT_FOUND.getCode());
        assertThat(response.getError().getMessage()).isEqualTo(ErrorCode.NOT_FOUND.getMessage());
    }

    @Test
    void errorFromErrorCodeUsesCustomMessage() {
        // when
        ApiResponseDto<Void> response = ApiResponseDto.error(ErrorCode.VALIDATION_ERROR, "bad request");

        // then
        assertThat(response.isSuccess()).isFalse();
        assertThat(response.getError().getCode()).isEqualTo(ErrorCode.VALIDATION_ERROR.getCode());
        assertThat(response.getError().getMessage()).isEqualTo("bad request");
    }
}
