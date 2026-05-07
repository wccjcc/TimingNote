import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_provider.dart';
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
  }) async {
    final envelope = await _client.post<NotificationActionResult>(
      '${ApiEndpoints.notifications}/$notificationId/actions',
      data: {
        'actionType': actionType,
        if (snoozeMinutes != null) 'snoozeMinutes': snoozeMinutes,
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
}

