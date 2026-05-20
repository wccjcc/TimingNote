import 'dart:math' as math;

/// 두 좌표 사이의 대원 거리를 미터 단위로 반환한다 (Haversine).
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

/// 거리(m)를 사람 읽기 좋은 표기로 변환. 1km 미만은 정수 m, 이상은 소수 1자리 km.
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()}m';
  }
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(1)}km';
}

double _toRad(double deg) => deg * math.pi / 180.0;
