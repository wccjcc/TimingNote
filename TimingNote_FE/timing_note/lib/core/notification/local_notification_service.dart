import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 로컬 알림 서비스
/// - 초기화
/// - 테스트 알림 1건 표시
class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 앱 시작 시 1회 호출
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Android 초기화 설정
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const ios = DarwinInitializationSettings(
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    // v21: settings는 named parameter
    await _plugin.initialize(
      settings: settings,
    );

    _initialized = true;
  }

  /// 로컬 알림 테스트용
  Future<void> showTestNotification({
    String title = '테스트 알림',
    String body = '로컬 알림이 정상 동작합니다.',
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'timing_note_default_channel',
      'Timing Note Default',
      channelDescription: '기본 알림 채널',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // v21: show도 named parameter
    await _plugin.show(
      id: 1001,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showGeofenceNotification({
    required String geofenceId,
    required String transition,
    required String occurredAt,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'timing_note_geofence_channel',
      'Timing Note Geofence',
      channelDescription: 'Geofence transition notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Geofence $transition',
      body: '$geofenceId at $occurredAt',
      notificationDetails: details,
    );
  }
}
