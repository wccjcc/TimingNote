import 'geofence_service.dart';

/// 백엔드 연동 전까지 프론트에서 고정으로 사용할 geofence 목록입니다.
///
/// 운영에서는 서버에서 사용자별/상황별 geofence를 내려주는 형태로 바뀔 수 있으므로,
/// 이 파일은 "임시 하드코딩 데이터"를 모아둔 위치라고 보면 됩니다.
class GeofenceHardcodedRegions {
  static const List<GeofenceRegion> regions = <GeofenceRegion>[
    GeofenceRegion(
      id: 'ssafy-seoul-campus',
      latitude: 37.501274,
      longitude: 127.039585,
      radius: 120,
    ),
    GeofenceRegion(
      id: 'gangnam-station',
      latitude: 37.497942,
      longitude: 127.027621,
      radius: 150,
    ),
  ];
}
