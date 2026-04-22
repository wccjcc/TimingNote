class ApiEndpoints {
  static const String todos = '/todos';
  static const String recommendations = '/recommendations';
  static const String placesSearch = '/places/search';

  /// geofence enter/exit 이벤트 업로드 endpoint
  static const String geofenceEvents = '/geofences/events';

  /// X-Device-Secret 헤더 제외 endpoint (device_secret)
  static const String sys01 = '/v1/users';
}
