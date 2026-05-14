class ApiEndpoints {
  /// SYS-01 디바이스 등록 endpoint
  static const String users = '/users';

  static const String todos = '/todos';

  static const String recommendations = '/recommendations';
  static const String userPlaces = '/user-places';
  static const String userSettings = '/users/me/settings';
  static const String imageUploadUrl = '/images/upload-url';
  static const String imageDownloadUrls = '/images/download-urls';

  /// FCM 토큰 최초 등록/갱신 endpoint
  static const String fcmTokens = '/fcm/tokens';

  /// Geofence 이벤트 전송 endpoint
  static const String geofenceEvents = '/geofence/events';
  static const String geofenceRecalculate = '/geofence/recalculate';
  static const String notifications = '/notifications';
  static const String geofenceSlots = '/notifications/geofence/slots';
  static const String geofenceSlotsStream =
      '/notifications/geofence/slots/stream';

  /// 장소 검색 프록시 (BE → Kakao Local API). Kakao REST key 격리 목적.
  static const String placesSearch = '/places/search';
  static const String placesReverseGeocode = '/places/reverse-geocode';
}
