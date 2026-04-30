class ApiEndpoints {
  /// SYS-01 디바이스 등록 endpoint
  static const String users = '/users';

  static const String todos = '/todos';

  static const String recommendations = '/recommendations';
  static const String placesSearch = '/places/search';

  /// FCM 토큰 최초 등록/갱신 endpoint
  static const String fcmTokens = '/fcm/tokens';

  /// Geofence 이벤트 전송 endpoint
  static const String geofenceEvents = '/geofence/events';
}
