package com.timingnote.api.domain.fcm_test.service;

import com.timingnote.api.domain.fcm_test.dto.request.FcmGeofenceTestSendRequestDto;
import com.timingnote.api.domain.notification.dto.response.NotificationGeofenceSendResponseDto;

public interface FcmTestService {

    NotificationGeofenceSendResponseDto sendGeofenceStylePush(Long slotId, FcmGeofenceTestSendRequestDto requestDto);
}
