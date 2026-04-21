import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../location/location_permission_service.dart';
import '../notification/local_notification_service.dart';
import 'geofence_event.dart';
import 'geofence_event_publisher.dart';
import 'geofence_hardcoded_regions.dart';
import 'geofence_region_store.dart';
import 'geofence_service.dart';
import 'native_geofence_bridge.dart';

/// Geofence 런타임 오케스트레이터
///
/// 역할
/// 1) 감시 목록 로딩/저장
/// 2) 네이티브 geofence 등록 시작
/// 3) 전환 이벤트를 백엔드 publish로 전달
class GeofenceRuntime {
  GeofenceRuntime({
    required GeofenceService geofenceService,
    required GeofenceEventPublisher publisher,
    required GeofenceRegionStore regionStore,
    required LocalNotificationService localNotificationService,
  })  : _geofenceService = geofenceService,
        _publisher = publisher,
        _regionStore = regionStore,
        _localNotificationService = localNotificationService;

  final GeofenceService _geofenceService;
  final GeofenceEventPublisher _publisher;
  final GeofenceRegionStore _regionStore;
  final LocalNotificationService _localNotificationService;
  final Logger _logger = Logger();

  bool _started = false;

  bool get isStarted => _started;

  /// Geofence 모니터링 시작
  Future<void> start() async {
    if (_started) {
      return;
    }

    // 1) 로컬 저장 목록 우선 사용, 없으면 하드코딩 기본 목록 사용
    final storedRegions = await _regionStore.loadRegions();
    final regionsToRegister =
        storedRegions.isNotEmpty ? storedRegions : GeofenceHardcodedRegions.regions;

    // 2) 실제 등록 대상 목록을 로컬에 저장
    await _regionStore.saveRegions(regionsToRegister);

    // 3) 네이티브 등록 + 전환 이벤트 처리
    await _geofenceService.registerGeofences(
      regionsToRegister,
      onTransition: (transitionEvent) async {
        final event = GeofenceEvent(
          eventId: transitionEvent.eventId.isNotEmpty
              ? transitionEvent.eventId
              : _newFallbackEventId(transitionEvent),
          geofenceId: transitionEvent.geofenceId,
          transition: transitionEvent.transition,
          occurredAt: transitionEvent.occurredAt,
          latitude: transitionEvent.latitude,
          longitude: transitionEvent.longitude,
          accuracyMeters: transitionEvent.accuracyMeters,
        );

        try {
          await _localNotificationService.showGeofenceNotification(
            geofenceId: event.geofenceId,
            transition: event.transition.name.toUpperCase(),
            occurredAt: event.occurredAt.toLocal().toIso8601String(),
          );

          await _publisher.publish(event);
          _logger.i(
            '[GEOFENCE_PUBLISHED] '
            '${event.transition.name} ${event.geofenceId} '
            '${event.occurredAt.toIso8601String()}',
          );
        } catch (e) {
          // TODO: 실패 이벤트 로컬 큐 저장 후 재시도 연결
          _logger.e('[GEOFENCE_PUBLISH_FAILED] ${event.geofenceId} $e');
        }
      },
    );

    _started = true;
    _logger.i('[GEOFENCE_MONITORING_STARTED] regions=${regionsToRegister.length}');
  }

  Future<void> stop() async {
    await _geofenceService.clearGeofences();
    _started = false;
    _logger.i('[GEOFENCE_MONITORING_STOPPED]');
  }

  /// 네이티브 eventId가 비어있을 때 사용할 fallback ID
  String _newFallbackEventId(GeofenceTransitionEvent event) {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return '${event.geofenceId}_${event.transition.name}_${event.occurredAt.microsecondsSinceEpoch}_$random';
  }
}

final locationPermissionServiceProvider = Provider<LocationPermissionService>((ref) {
  return LocationPermissionService();
});

final nativeGeofenceBridgeProvider = Provider<NativeGeofenceBridge>((ref) {
  return NativeGeofenceBridge();
});

final geofenceRegionStoreProvider = Provider<GeofenceRegionStore>((ref) {
  return GeofenceRegionStore();
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  return GeofenceService(
    permissionService: ref.read(locationPermissionServiceProvider),
    nativeBridge: ref.read(nativeGeofenceBridgeProvider),
  );
});

final geofenceRuntimeProvider = Provider<GeofenceRuntime>((ref) {
  return GeofenceRuntime(
    geofenceService: ref.read(geofenceServiceProvider),
    publisher: ref.read(geofenceEventPublisherProvider),
    regionStore: ref.read(geofenceRegionStoreProvider),
    localNotificationService: ref.read(localNotificationServiceProvider),
  );
});
