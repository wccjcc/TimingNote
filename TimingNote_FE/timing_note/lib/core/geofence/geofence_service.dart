import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../location/location_permission_service.dart';
import '../network/api_exception.dart';
import 'geofence_event.dart';
import 'native_geofence_bridge.dart';

/// geofence 영역 모델
///
/// 네이티브 API(Android/iOS)로 그대로 전달되는 기본 단위입니다.
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  /// 로컬 저장소에서 복원할 때 사용하는 역직렬화 팩토리입니다.
  factory GeofenceRegion.fromJson(Map<String, dynamic> json) {
    return GeofenceRegion(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 네이티브 geofence 이벤트를 앱 내부 표준 모델로 변환한 결과입니다.
class GeofenceTransitionEvent {
  final String eventId;
  final String geofenceId;
  final GeofenceTransitionType transition;
  final DateTime occurredAt;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  const GeofenceTransitionEvent({
    required this.eventId,
    required this.geofenceId,
    required this.transition,
    required this.occurredAt,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });
}

/// geofence 등록/해제와 네이티브 이벤트 구독을 담당하는 서비스
///
/// 동작 순서
/// 1) 위치 권한(WhenInUse + Always)을 확인/요청
/// 2) 네이티브 모듈에 geofence 목록 등록
/// 3) 네이티브 EventChannel에서 enter/exit 이벤트 수신
/// 4) 수신 이벤트를 callback으로 상위 레이어(runtime)에 전달
class GeofenceService {
  GeofenceService({
    required LocationPermissionService permissionService,
    required NativeGeofenceBridge nativeBridge,
  })  : _permissionService = permissionService,
        _nativeBridge = nativeBridge;

  final LocationPermissionService _permissionService;
  final NativeGeofenceBridge _nativeBridge;

  StreamSubscription<Map<String, dynamic>>? _nativeEventSubscription;

  Future<void> registerGeofences(
    List<GeofenceRegion> regions, {
    required FutureOr<void> Function(GeofenceTransitionEvent event) onTransition,
  }) async {
    if (regions.isEmpty) {
      throw const ApiException(
        code: 'GEOFENCE_REGIONS_EMPTY',
        message: '등록할 geofence 영역이 비어 있습니다.',
      );
    }

    // 1) 권한 확보: 앱 사용 중 권한
    var whenInUseGranted = await _permissionService.isWhenInUseGranted();
    if (!whenInUseGranted) {
      await _permissionService.requestWhenInUse();
      whenInUseGranted = await _permissionService.isWhenInUseGranted();
    }

    if (!whenInUseGranted) {
      throw const ApiException(
        code: 'LOCATION_PERMISSION_DENIED',
        message: '위치 권한(앱 사용 중)이 필요합니다.',
      );
    }

    // 2) 권한 확보: 백그라운드 geofence를 위한 항상 허용 권한
    var alwaysGranted = await _permissionService.isAlwaysGranted();
    if (!alwaysGranted) {
      await _permissionService.requestAlways();
      alwaysGranted = await _permissionService.isAlwaysGranted();
    }

    if (!alwaysGranted) {
      throw const ApiException(
        code: 'LOCATION_ALWAYS_PERMISSION_DENIED',
        message: '백그라운드 geofence 감지를 위해 항상 허용 권한이 필요합니다.',
      );
    }

    // 기존 구독이 있으면 먼저 정리해 중복 이벤트 수신을 방지합니다.
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;

    // 3) 네이티브 등록
    await _nativeBridge.registerGeofences(
      regions.map((region) => region.toJson()).toList(growable: false),
    );

    // 4) 네이티브 이벤트 구독
    _nativeEventSubscription = _nativeBridge.events.listen((raw) {
      final transitionRaw = raw['transition']?.toString().toUpperCase();
      final transition = transitionRaw == 'ENTER'
          ? GeofenceTransitionType.enter
          : GeofenceTransitionType.exit;

      final occurredAtRaw = raw['occurredAt']?.toString();
      final occurredAt = occurredAtRaw == null
          ? DateTime.now().toUtc()
          : DateTime.tryParse(occurredAtRaw)?.toUtc() ?? DateTime.now().toUtc();

      final parsed = GeofenceTransitionEvent(
        eventId: raw['eventId']?.toString() ??
            'evt_${DateTime.now().microsecondsSinceEpoch}',
        geofenceId: raw['geofenceId']?.toString() ?? 'unknown',
        transition: transition,
        occurredAt: occurredAt,
        latitude: (raw['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (raw['longitude'] as num?)?.toDouble() ?? 0,
        accuracyMeters: (raw['accuracyMeters'] as num?)?.toDouble(),
      );

      onTransition(parsed);
    });
  }

  Future<void> clearGeofences() async {
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
    await _nativeBridge.clearGeofences();
  }
}
