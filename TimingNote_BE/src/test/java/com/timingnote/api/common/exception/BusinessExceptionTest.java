package com.timingnote.api.common.exception;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Modifier;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class BusinessExceptionTest {

    @Test
    void constructorStoresErrorCodeMessageAndData() {
        // given
        Map<String, Object> data = Map.of("limit", 5);

        // when
        BusinessException exception = new BusinessException("custom message", ErrorCode.VALIDATION_ERROR, data);

        // then
        assertThat(exception.getMessage()).isEqualTo("custom message");
        assertThat(exception.getErrorCode()).isEqualTo(ErrorCode.VALIDATION_ERROR);
        assertThat(exception.getData()).isEqualTo(data);
    }

    @Test
    void dataFieldIsTransientBecauseRuntimeExceptionIsSerializable() throws NoSuchFieldException {
        // when
        int modifiers = BusinessException.class.getDeclaredField("data").getModifiers();

        // then
        assertThat(Modifier.isTransient(modifiers)).isTrue();
    }
}
