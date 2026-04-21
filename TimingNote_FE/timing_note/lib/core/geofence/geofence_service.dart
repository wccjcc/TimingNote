/// geofence 하나를 표현하는 모델
/// - id: geofence 식별자(중복되면 안 됨)
/// - latitude/longitude: 중심 좌표
/// - radius: 반경(meter)
class GeofenceRegion {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;

  const GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

/// geofence 공통 서비스(현재는 스텁)
/// 지금 단계에서는 백엔드 호출/플랫폼 연동 없이
/// "인터페이스(메서드 시그니처)"만 먼저 고정한다.
class GeofenceService {
  /// geofence 목록 등록
  ///
  /// 현재 단계:
  /// - 구현하지 않고 TODO만 유지
  ///
  /// 추후 구현 계획:
  /// 1) 백엔드가 내려준 geofence 목록을 인자로 받음
  /// 2) iOS geofence 등록 API(플러그인/플랫폼 채널)와 연결
  Future<void> registerGeofences(List<GeofenceRegion> regions) async {
    // TODO: geofence 플랫폼 등록 로직 연결
    // 예) geofence plugin 호출 또는 MethodChannel로 네이티브 연결
    // 참고) 어떤 20개를 고를지는 백엔드 책임, 프론트는 받은 목록 등록만 담당
  }

  /// 등록된 geofence 전체 해제
  ///
  /// 현재 단계:
  /// - 구현하지 않고 TODO만 유지
  ///
  /// 추후 구현 계획:
  /// 1) iOS geofence 모니터링 해제 API와 연결
  Future<void> clearGeofences() async {
    // TODO: 등록된 geofence 전체 해제 로직 연결
  }
}
