import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_permission_service.dart';
import 'location_service.dart';

/// LocationService Riverpod provider — ViewModel에서 ref.read로 주입.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(LocationPermissionService());
});

/// API 호출 직전 사용자 위치 정보 스냅샷.
///
/// BE 후보 재계산이 요구하는 4개 필드를 한 번에 묶음:
/// - latitude/longitude: 사용자 현재 좌표
/// - course: 이동 방향 (iOS CLLocation.course, degree). 정지 시 null.
/// - occurredAt: 위치 측정 시각 (ISO-8601). geolocator의 Position.timestamp.
class GpsSnapshot {
  const GpsSnapshot({
    required this.latitude,
    required this.longitude,
    this.course,
    required this.occurredAt,
  });

  final double latitude;
  final double longitude;
  final double? course;
  final DateTime occurredAt;
}

/// API 호출 직전 GPS 좌표 + course + 측정 시각을 가져오는 헬퍼.
/// 권한 거부 / GPS 실패 시 null 반환 (throw 안 함).
Future<GpsSnapshot?> tryGetGpsSnapshot(Ref ref) async {
  try {
    final pos = await ref.read(locationServiceProvider).getCurrentPosition();
    // heading은 정지 상태(speed≈0)일 때 -1 또는 NaN 반환 — null로 정규화
    final hasHeading = pos.heading.isFinite && pos.heading >= 0;
    return GpsSnapshot(
      latitude: pos.latitude,
      longitude: pos.longitude,
      course: hasHeading ? pos.heading : null,
      occurredAt: pos.timestamp,
    );
  } catch (_) {
    return null;
  }
}

