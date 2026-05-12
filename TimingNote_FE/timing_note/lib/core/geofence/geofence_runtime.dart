import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/notification/service/notification_service.dart';
import '../location/location_permission_service.dart';
import 'geofence_event.dart';
import 'geofence_region_store.dart';
import 'geofence_service.dart';
import 'geofence_sse_client.dart';
import 'native_geofence_bridge.dart';

/// Geofence 런타임 오케스트레이션 클래스입니다.
///
/// 책임:
/// 1) 앱 시작 시 geofence 감시 초기화
/// 2) geofence 진입 이벤트 발생 시 NOTI-05 호출
/// 3) SSE 신호를 받아 서버 슬롯 재조회 후 감시 목록 갱신
class GeofenceRuntime {
  GeofenceRuntime({
    required GeofenceService geofenceService,
    required GeofenceRegionStore regionStore,
    required GeofenceSseClient geofenceSseClient,
    required NotificationService notificationService,
  }) : _geofenceService = geofenceService,
       _regionStore = regionStore,
       _geofenceSseClient = geofenceSseClient,
       _notificationService = notificationService;

  final GeofenceService _geofenceService;
  final GeofenceRegionStore _regionStore;
  final GeofenceSseClient _geofenceSseClient;
  final NotificationService _notificationService;
  final Logger _logger = Logger();

  bool _started = false;
  StreamSubscription? _sseSignalSubscription;
  Timer? _slotsRefreshDebounceTimer;

  bool get isStarted => _started;

  /// Geofence 감시를 시작합니다.
  Future<void> start() async {
    if (_started) {
      // 이미 감시 중이면 실시간 동기화(SSE)만 재개합니다.
      await resumeRealtimeSync();
      return;
    }

    final storedRegions = await _regionStore.loadRegions();
    if (storedRegions.isNotEmpty) {
      await _regionStore.saveRegions(storedRegions);
      await _geofenceService.registerGeofences(
        storedRegions,
        onTransition: _handleTransition,
      );
    } else {
      _logger.i(
        '[GEOFENCE_MONITORING_STARTED] no cached regions, waiting server slots',
      );
    }

    _started = true;
    if (storedRegions.isNotEmpty) {
      _logger.i(
        '[GEOFENCE_MONITORING_STARTED] regions=${storedRegions.length}',
      );
    }

    await _startSlotsSignalSync();
  }

  /// Geofence 감시를 완전히 중지합니다.
  ///
  /// 주의:
  /// - 일반적인 background 전환에서는 이 메서드를 쓰지 않습니다.
  /// - background에서는 geofence 감시는 유지하고, SSE만 끊어야 하므로
  ///   [pauseRealtimeSync]를 사용합니다.
  Future<void> stop() async {
    await pauseRealtimeSync();
    await _geofenceService.clearGeofences();

    _started = false;
    _logger.i('[GEOFENCE_MONITORING_STOPPED]');
  }

  /// 실시간 동기화(SSE + 슬롯 재조회 트리거)만 일시 중지합니다.
  ///
  /// 사용 시점:
  /// - 앱이 paused/background로 내려갈 때
  /// - geofence 감시는 유지하고 네트워크 동기화만 멈추고 싶을 때
  Future<void> pauseRealtimeSync() async {
    _slotsRefreshDebounceTimer?.cancel();
    _slotsRefreshDebounceTimer = null;

    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = null;

    await _geofenceSseClient.stop();
    _logger.i('[GEOFENCE_REALTIME_SYNC_PAUSED]');
  }

  /// 실시간 동기화(SSE)를 재개합니다.
  Future<void> resumeRealtimeSync() async {
    if (!_started) {
      return;
    }
    await _startSlotsSignalSync();
    _logger.i('[GEOFENCE_REALTIME_SYNC_RESUMED]');
  }

  /// SSE 신호 수신 파이프라인을 시작합니다.
  Future<void> _startSlotsSignalSync() async {
    await _geofenceSseClient.start();
    await _refreshSlots();

    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = _geofenceSseClient.signals.listen((signal) {
      // 서버는 SSE 연결 직후 "connected" 이벤트를 보내 연결 수립만 알려줍니다.
      // 슬롯 변경이 아닌 연결 확인 이벤트까지 새로고침 트리거로 쓰면,
      // 재연결/화면 전환 시 불필요한 GET /geofence/slots 요청이 반복됩니다.
      if (signal.event != 'slots-updated') {
        _logger.i('[GEOFENCE_SSE_SIGNAL] event=${signal.event} action=ignored');
        return;
      }

      _slotsRefreshDebounceTimer?.cancel();
      _slotsRefreshDebounceTimer = Timer(const Duration(seconds: 1), () {
        _refreshSlots();
      });

      _logger.i(
        '[GEOFENCE_SSE_SIGNAL] event=${signal.event} action=refresh_scheduled',
      );
    });
  }

  /// 외부(앱 lifecycle 등)에서 강제로 슬롯 동기화를 요청할 때 사용합니다.
  Future<void> syncSlots() async {
    await _refreshSlots();
  }

  /// 서버의 최신 geofence 슬롯 목록을 조회하고 네이티브 감시에 반영합니다.
  Future<void> _refreshSlots() async {
    try {
      final slotsResponse = await _notificationService.getGeofenceSlots();

      final regions = slotsResponse.slots
          .where((slot) => slot.active)
          .where((slot) => slot.latitude != null && slot.longitude != null)
          .where((slot) => slot.radiusM != null && slot.radiusM! > 0)
          .map(
            (slot) => GeofenceRegion(
              id: 'slot_${slot.slotId}',
              latitude: slot.latitude!,
              longitude: slot.longitude!,
              radius: slot.radiusM!.toDouble(),
            ),
          )
          .toList(growable: false);

      if (regions.isEmpty) {
        await _geofenceService.clearGeofences();
        await _regionStore.saveRegions(const <GeofenceRegion>[]);

        _logger.i(
          '[GEOFENCE_SLOTS_APPLIED] count=0 action=cleared '
          'lastCalculatedAt=${slotsResponse.lastCalculatedAt?.toIso8601String()}',
        );
        return;
      }

      await _geofenceService.registerGeofences(
        regions,
        onTransition: _handleTransition,
      );
      await _regionStore.saveRegions(regions);

      _logger.i(
        '[GEOFENCE_SLOTS_REFRESHED] '
        'count=${slotsResponse.slots.length} '
        'applied=${regions.length} '
        'lastCalculatedAt=${slotsResponse.lastCalculatedAt?.toIso8601String()}',
      );
    } catch (e) {
      _logger.e('[GEOFENCE_SLOTS_REFRESH_FAILED] $e');
    }
  }

  /// geofence 이벤트에서 slotId를 파싱해 NOTI-05를 호출합니다.
  ///
  /// 정책:
  /// - ENTER 이벤트에서만 호출(도착 시점 알림)
  /// - geofenceId는 slot_{id} 형식으로 가정
  Future<void> _handleTransition(
    GeofenceTransitionEvent transitionEvent,
  ) async {
    if (transitionEvent.transition ==
        GeofenceTransitionType.significantChange) {
      await _handleSignificantLocationChange(transitionEvent);
      return;
    }

    final slotId = _extractSlotId(transitionEvent.geofenceId);
    if (slotId == null) {
      _logger.w(
        '[GEOFENCE_NOTI_SKIP] invalid geofenceId=${transitionEvent.geofenceId}',
      );
      return;
    }

    try {
      final sent = await _notificationService.sendGeofenceNotification(slotId);
      _logger.i(
        '[GEOFENCE_NOTI_REQUESTED] '
        'slotId=$slotId transition=${transitionEvent.transition.name} sent=$sent',
      );
    } catch (e) {
      _logger.e(
        '[GEOFENCE_NOTI_FAILED] '
        'slotId=$slotId transition=${transitionEvent.transition.name} error=$e',
      );
    }
  }

  int? _extractSlotId(String geofenceId) {
    if (!geofenceId.startsWith('slot_')) {
      return null;
    }
    return int.tryParse(geofenceId.substring(5));
  }

  /// iOS significant-change 이벤트를 받아 geofence 슬롯 재계산을 요청합니다.
  ///
  /// 이 경로는 ENTER/EXIT 알림 발사와 목적이 다르므로,
  /// slotId 파싱 없이 위치 좌표 기반 재계산 API만 호출합니다.
  Future<void> _handleSignificantLocationChange(
    GeofenceTransitionEvent transitionEvent,
  ) async {
    try {
      await _notificationService.requestGeofenceRecalculation(
        latitude: transitionEvent.latitude,
        longitude: transitionEvent.longitude,
        occurredAt: transitionEvent.occurredAt,
        course: transitionEvent.course,
      );
      _logger.i(
        '[GEOFENCE_RECALCULATE_REQUESTED] '
        'source=significant_change lat=${transitionEvent.latitude} '
        'lng=${transitionEvent.longitude}',
      );
    } catch (e) {
      _logger.w('[GEOFENCE_RECALCULATE_FAILED] source=significant_change $e');
    }
  }
}

final locationPermissionServiceProvider = Provider<LocationPermissionService>((
  ref,
) {
  return LocationPermissionService();
});

final nativeGeofenceBridgeProvider = Provider<NativeGeofenceBridge>((ref) {
  return NativeGeofenceBridge();
});

final geofenceRegionStoreProvider = Provider<GeofenceRegionStore>((ref) {
  return GeofenceRegionStore();
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
    regionStore: ref.read(geofenceRegionStoreProvider),
    geofenceSseClient: ref.read(geofenceSseClientProvider),
    notificationService: ref.read(notificationServiceProvider),
  );
});
