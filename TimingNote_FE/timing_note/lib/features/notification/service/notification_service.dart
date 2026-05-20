import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_provider.dart';
import 'package:timing_note/features/notification/model/geofence_slots.dart';
import 'package:timing_note/features/notification/model/notification_item.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(apiClient: ref.read(apiClientProvider));
});

class NotificationService {
  NotificationService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<NotificationPage> getNotifications({
    int? todoId,
    int page = 0,
    int size = 50,
  }) async {
    final envelope = await _client.get<NotificationPage>(
      ApiEndpoints.notifications,
      queryParameters: {
        if (todoId != null) 'todoId': todoId,
        'page': page,
        'size': size,
      },
      dataParser: (json) => NotificationPage.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<NotificationActionResult> applyAction({
    required int notificationId,
    required String actionType,
    int? snoozeMinutes,
    double? latitude,
    double? longitude,
    double? course,
  }) async {
    final envelope = await _client.post<NotificationActionResult>(
      '${ApiEndpoints.notifications}/$notificationId/actions',
      data: {
        'actionType': actionType,
        if (snoozeMinutes != null) 'snoozeMinutes': snoozeMinutes,
        // 확장성을 위해 위치 키는 항상 포함합니다.
        // 값이 없으면 null로 전송되어 백엔드에서 정책에 맞게 처리할 수 있습니다.
        'latitude': latitude,
        'longitude': longitude,
        'course': course,
      },
      dataParser: (json) =>
          NotificationActionResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<void> markAsRead(int notificationId) async {
    await _client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.notifications}/$notificationId',
      data: const {'isRead': true},
      dataParser: (json) => (json as Map<String, dynamic>),
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    await _client.delete<Map<String, dynamic>>(
      '${ApiEndpoints.notifications}/$notificationId',
      dataParser: (json) => (json as Map<String, dynamic>),
    );
  }

  /// NOTI-05: geofence 슬롯 기준으로 서버 푸시 알림 발송을 요청합니다.
  ///
  /// 반환값은 서버 응답의 sent 필드를 우선 사용하고,
  /// 필드가 없으면 요청 성공 자체를 true로 간주합니다.
  Future<bool> sendGeofenceNotification(int slotId) async {
    final envelope = await _client.get<Map<String, dynamic>>(
      '${ApiEndpoints.notifications}/geofence/$slotId',
      dataParser: (json) => json as Map<String, dynamic>,
    );

    final data = envelope.data;
    if (data == null) {
      return true;
    }
    return data['sent'] != false;
  }

  /// 서버가 현재 계산해둔 geofence 슬롯 목록을 조회합니다.
  ///
  /// SSE는 "슬롯이 바뀌었다"는 신호만 전달하므로,
  /// 실제 최신 상태는 이 API를 다시 호출해서 동기화합니다.
  Future<GeofenceSlotsResponse> getGeofenceSlots() async {
    final envelope = await _client.get<GeofenceSlotsResponse>(
      ApiEndpoints.geofenceSlots,
      dataParser: (json) =>
          GeofenceSlotsResponse.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  /// 유의미한 위치 변화(특히 iOS significant-change) 시 geofence 슬롯 재계산을 요청합니다.
  ///
  /// 서버는 이 요청을 비동기 outbox -> consumer 경로로 처리하므로,
  /// 클라이언트는 accepted 응답만 받으면 됩니다.
  Future<void> requestGeofenceRecalculation({
    required double latitude,
    required double longitude,
    required DateTime occurredAt,
    double? course,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.geofenceRecalculate,
      data: {
        'latitude': latitude,
        'longitude': longitude,
        // 백엔드 DTO의 occurredAt은 필수값입니다.
        // 네이티브에서 받은 이벤트 시각을 UTC ISO 문자열로 보내 validation 400을 막습니다.
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (course != null) 'course': course,
      },
      dataParser: (json) => json as Map<String, dynamic>,
    );
  }
}
