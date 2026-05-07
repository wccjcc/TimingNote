import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../location/location_permission_service.dart';
import '../notification/local_notification_service.dart';
import '../../features/notification/service/notification_service.dart';
import 'geofence_event.dart';
import 'geofence_event_publisher.dart';
import 'geofence_hardcoded_regions.dart';
import 'geofence_region_store.dart';
import 'geofence_service.dart';
import 'geofence_sse_client.dart';
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
    required GeofenceSseClient geofenceSseClient,
    required NotificationService notificationService,
  })  : _geofenceService = geofenceService,
        _publisher = publisher,
        _regionStore = regionStore,
        _localNotificationService = localNotificationService,
        _geofenceSseClient = geofenceSseClient,
        _notificationService = notificationService;

  final GeofenceService _geofenceService;
  final GeofenceEventPublisher _publisher;
  final GeofenceRegionStore _regionStore;
  final LocalNotificationService _localNotificationService;
  final GeofenceSseClient _geofenceSseClient;
  final NotificationService _notificationService;
  final Logger _logger = Logger();

  bool _started = false;
  StreamSubscription? _sseSignalSubscription;
  Timer? _slotsRefreshDebounceTimer;

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

    // SSE 구독을 시작합니다.
    //
    // 동작 의도:
    // - 서버에서 "slot 갱신" 신호가 오면 실제 slot 목록을 재조회합니다.
    // - 신호 폭주 시 불필요한 API 중복 호출을 막기 위해 디바운스를 적용합니다.
    await _startSlotsSignalSync();
  }

  Future<void> stop() async {
    // 런타임 정지 시 SSE 관련 리소스부터 먼저 정리합니다.
    // (재연결 타이머가 남아 있으면 stop 이후에도 네트워크 요청이 발생할 수 있습니다.)
    _slotsRefreshDebounceTimer?.cancel();
    _slotsRefreshDebounceTimer = null;
    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = null;
    await _geofenceSseClient.stop();

    await _geofenceService.clearGeofences();
    _started = false;
    _logger.i('[GEOFENCE_MONITORING_STOPPED]');
  }

  /// SSE 신호 기반 slot 재조회 파이프라인을 시작합니다.
  Future<void> _startSlotsSignalSync() async {
    await _geofenceSseClient.start();

    // 연결 직후 1회 재조회해서 SSE 수신 이전 상태 공백을 줄입니다.
    await _refreshSlots();

    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = _geofenceSseClient.signals.listen((signal) {
      // 서버가 짧은 시간에 이벤트를 여러 번 보낼 수 있으므로,
      // 마지막 신호 기준으로 1회만 조회하도록 디바운스를 적용합니다.
      _slotsRefreshDebounceTimer?.cancel();
      _slotsRefreshDebounceTimer = Timer(const Duration(seconds: 1), () {
        _refreshSlots();
      });

      _logger.i('[GEOFENCE_SSE_SIGNAL] event=${signal.event}');
    });
  }

  /// 서버의 최신 geofence slot 목록을 조회합니다.
  ///
  /// 현재 단계에서는 "신호 수신 -> 슬롯 재조회 연결"까지 구현하고,
  /// slot -> 실제 region 적용은 다음 단계에서 이어서 연결합니다.
  Future<void> _refreshSlots() async {
    try {
      final slotsResponse = await _notificationService.getGeofenceSlots();
      _logger.i(
        '[GEOFENCE_SLOTS_REFRESHED] '
        'count=${slotsResponse.slots.length} '
        'lastCalculatedAt=${slotsResponse.lastCalculatedAt?.toIso8601String()}',
      );
    } catch (e) {
      _logger.e('[GEOFENCE_SLOTS_REFRESH_FAILED] $e');
    }
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
    geofenceSseClient: ref.read(geofenceSseClientProvider),
    notificationService: ref.read(notificationServiceProvider),
  );
});
