class ApiEndpoints {
  /// SYS-01 디바이스 등록 endpoint
  static const String users = '/v1/users';

  static const String todos = '/todos';
  static const String recommendations = '/recommendations';
  static const String placesSearch = '/places/search';

  /// geofence enter/exit 이벤트 업로드 endpoint
  static const String geofenceEvents = '/geofences/events';

  /// FCM 토큰 최초 등록/갱신 endpoint
  static const String fcmTokens = '/v1/fcm/tokens';

  /// X-Device-Secret 헤더 제외 예시 endpoint
  static const String sys01 = '/sys/01';
}
