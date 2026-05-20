import 'package:flutter/foundation.dart' show debugPrint;
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

/// 최근 GPS 스냅샷 캐시. 표시용 호출(거리·라벨 등)은 이 캐시를 재사용해 배터리·응답 시간을 절감.
/// 알림 트리거(슬롯 재계산)도 [_kFreshTtl] 안이면 재사용 — 빠른 연속 액션 시 GPS hw 반복 활성 방지.
GpsSnapshot? _cachedSnapshot;
DateTime? _cachedAt;

/// 표시용 호출의 캐시 유효 시간. 거리 라벨 등 UI 표시는 약간 stale 해도 무방.
const Duration _kCacheTtl = Duration(seconds: 120);

/// 트리거용(forceFresh=true) 호출의 "초신선" 기준. 이 안이면 새 측정 없이 재사용해도
/// 슬롯 재계산 정확도에 사실상 차이 없음 → 빠른 연속 토글에서 GPS hw 활성 횟수 최소화.
const Duration _kFreshTtl = Duration(seconds: 30);

/// 캐시 무효화 — 권한 변화나 명시적 새로고침이 필요한 시점에 호출.
void invalidateGpsCache() {
  _cachedSnapshot = null;
  _cachedAt = null;
}

/// API 호출 직전 GPS 좌표 + course + 측정 시각을 가져오는 헬퍼.
/// 권한 거부 / GPS 실패 / timeout 시 null 반환 (throw 안 함).
///
/// [forceFresh]:
/// - false (기본): TTL(120s) 안의 캐시가 있으면 그대로 반환. **표시용** 호출에 사용.
/// - true: 초신선 TTL(30s) 안의 캐시만 재사용, 그 외엔 새 GPS 측정. **알림 트리거** 호출에 사용.
///   빠른 연속 액션(토글 여러 번)에서 GPS hw 반복 활성을 방지하면서도 슬롯 재계산 정확도 유지.
///
/// 신선한 측정이 성공하면 캐시도 갱신.
Future<GpsSnapshot?> tryGetGpsSnapshot(
  Object ref, {
  bool forceFresh = false,
}) async {
  // [GPS-LOG] 캐싱 흐름 단계별 추적 — debug 빌드에서만 출력 (release 자동 미출력).
  if (_cachedSnapshot != null && _cachedAt != null) {
    final age = DateTime.now().difference(_cachedAt!);
    final ttl = forceFresh ? _kFreshTtl : _kCacheTtl;
    if (age < ttl) {
      debugPrint(
        '[GPS] memory-cache HIT  | age=${age.inSeconds}s '
        '(ttl=${ttl.inSeconds}s, forceFresh=$forceFresh) | '
        'lat=${_cachedSnapshot!.latitude.toStringAsFixed(6)} '
        'lng=${_cachedSnapshot!.longitude.toStringAsFixed(6)} | '
        'measuredAt=${_cachedSnapshot!.occurredAt.toIso8601String()}',
      );
      return _cachedSnapshot;
    }
    debugPrint(
      '[GPS] memory-cache STALE | age=${age.inSeconds}s > ttl=${ttl.inSeconds}s '
      '→ LocationService 호출 (fastMode=${!forceFresh})',
    );
  } else {
    debugPrint(
      '[GPS] memory-cache EMPTY → LocationService 호출 (fastMode=${!forceFresh})',
    );
  }

  try {
    // 표시용(forceFresh=false)은 fastMode로 디바이스 캐시(getLastKnownPosition) 우선.
    // 알림 트리거(forceFresh=true)는 medium 정확도로 새 측정.
    final pos = await _readLocationService(
      ref,
    ).getCurrentPosition(fastMode: !forceFresh);
    // heading은 정지 상태(speed≈0)일 때 -1 또는 NaN 반환 — null로 정규화
    final hasHeading = pos.heading.isFinite && pos.heading >= 0;
    final snapshot = GpsSnapshot(
      latitude: pos.latitude,
      longitude: pos.longitude,
      course: hasHeading ? pos.heading : null,
      occurredAt: pos.timestamp,
    );
    _cachedSnapshot = snapshot;
    _cachedAt = DateTime.now();
    final measureAge = DateTime.now().difference(pos.timestamp);
    debugPrint(
      '[GPS] cache UPDATED      | '
      'lat=${pos.latitude.toStringAsFixed(6)} '
      'lng=${pos.longitude.toStringAsFixed(6)} | '
      'measuredAt=${pos.timestamp.toIso8601String()} (age=${measureAge.inSeconds}s)',
    );
    return snapshot;
  } catch (e) {
    debugPrint('[GPS] FAILED            | $e');
    return null;
  }
}

LocationService _readLocationService(Object ref) {
  if (ref is Ref) {
    return ref.read(locationServiceProvider);
  }
  if (ref is WidgetRef) {
    return ref.read(locationServiceProvider);
  }
  throw ArgumentError('Unsupported ref type: ${ref.runtimeType}');
}
