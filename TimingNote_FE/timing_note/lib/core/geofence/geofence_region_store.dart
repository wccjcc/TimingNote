import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'geofence_service.dart';

/// geofence 감시 목록을 "기기 로컬"에 저장/복원하는 저장소입니다.
///
/// 설계 의도
/// - 서버 없이도 앱 재실행 시 마지막 감시 목록을 복원할 수 있게 한다.
/// - 앱 삭제 시 데이터가 사라져도 괜찮다는 현재 정책(로컬 전용)에 맞춘다.
class GeofenceRegionStore {
  static const String _regionsKey = 'geofence_regions_v1';

  /// 감시 목록 전체를 로컬에 저장합니다.
  Future<void> saveRegions(List<GeofenceRegion> regions) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = regions.map((region) => region.toJson()).toList();
    await prefs.setString(_regionsKey, jsonEncode(payload));
  }

  /// 로컬에 저장된 감시 목록을 복원합니다.
  ///
  /// 반환 규칙
  /// - 저장 데이터가 없거나 파싱 실패 시 빈 목록 반환
  Future<List<GeofenceRegion>> loadRegions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_regionsKey);
    if (raw == null || raw.isEmpty) {
      return const <GeofenceRegion>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <GeofenceRegion>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(GeofenceRegion.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <GeofenceRegion>[];
    }
  }

  /// 저장된 감시 목록을 제거합니다.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_regionsKey);
  }
}

