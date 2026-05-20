package com.timingnote.api.domain.notification.dto.response;

import lombok.Builder;
import lombok.Getter;

/**
 * NOTI-05 위치 기반 알림 발송 결과 DTO.
 */
@Getter
@Builder
public class NotificationGeofenceSendResponseDto {

    private final boolean sent;
    private final String reason;
}
