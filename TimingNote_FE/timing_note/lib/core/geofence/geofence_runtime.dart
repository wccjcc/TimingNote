import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/notification/service/notification_service.dart';
import '../location/location_permission_service.dart';
import '../notification/local_notification_service.dart';
import 'geofence_event.dart';
import 'geofence_event_publisher.dart';
import 'geofence_region_store.dart';
import 'geofence_service.dart';
import 'geofence_sse_client.dart';
import 'native_geofence_bridge.dart';

/// Geofence 런타임 오케스트레이션 클래스입니다.
///
/// 책임:
/// 1) 앱 시작 시 geofence 감시 초기화
/// 2) 네이티브 geofence 이벤트 수신 시 알림/백엔드 전송
/// 3) SSE 신호를 받아 서버 슬롯 재조회 후 감시 목록 갱신
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

  /// Geofence 감시를 시작합니다.
  ///
  /// 동작 순서:
  /// - 로컬에 저장된 기존 region이 있으면 우선 사용
  /// - 저장된 region이 없으면 즉시 SSE/slots 동기화로 서버 기준 목록을 받음
  /// - 하드코딩 fallback은 사용하지 않음
  Future<void> start() async {
    if (_started) {
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
      // 앱 첫 실행/캐시 초기화 상태에서는 임시 하드코딩 region을 등록하지 않습니다.
      // 이 상태는 잠시 "미등록" 상태로 두고, 아래 슬롯 동기화가 완료되면 서버 기준으로 등록합니다.
      _logger.i('[GEOFENCE_MONITORING_STARTED] no cached regions, waiting server slots');
    }

    _started = true;
    if (storedRegions.isNotEmpty) {
      _logger.i('[GEOFENCE_MONITORING_STARTED] regions=${storedRegions.length}');
    }

    // SSE 슬롯 동기화를 시작합니다.
    // 연결 직후 1회 강제 재조회하여 초기 정합성을 맞춥니다.
    await _startSlotsSignalSync();
  }

  /// Geofence 감시를 중지합니다.
  Future<void> stop() async {
    // 1) 슬롯 재조회 관련 비동기 리소스 정리
    _slotsRefreshDebounceTimer?.cancel();
    _slotsRefreshDebounceTimer = null;

    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = null;

    await _geofenceSseClient.stop();

    // 2) 네이티브 geofence 감시 해제
    await _geofenceService.clearGeofences();

    _started = false;
    _logger.i('[GEOFENCE_MONITORING_STOPPED]');
  }

  /// SSE 신호 수신 파이프라인을 시작합니다.
  Future<void> _startSlotsSignalSync() async {
    await _geofenceSseClient.start();

    // 연결 성공 직후 1회 즉시 동기화
    await _refreshSlots();

    await _sseSignalSubscription?.cancel();
    _sseSignalSubscription = _geofenceSseClient.signals.listen((signal) {
      // 신호 폭주 시 API 과호출을 막기 위해 디바운스를 적용합니다.
      _slotsRefreshDebounceTimer?.cancel();
      _slotsRefreshDebounceTimer = Timer(const Duration(seconds: 1), () {
        _refreshSlots();
      });

      _logger.i('[GEOFENCE_SSE_SIGNAL] event=${signal.event}');
    });
  }

  /// 외부(앱 lifecycle 등)에서 강제로 슬롯 동기화를 요청할 때 사용하는 공개 메서드입니다.
  ///
  /// 사용 시점:
  /// - 앱이 background -> foreground(resumed)로 복귀했을 때
  /// - SSE 재연결 직후 정합성을 한 번 더 맞추고 싶을 때
  Future<void> syncSlots() async {
    await _refreshSlots();
  }

  /// 서버의 최신 geofence 슬롯 목록을 조회하고 네이티브 감시에 반영합니다.
  ///
  /// 정책:
  /// - 정상 응답에서 슬롯이 비어 있으면 전체 해제
  /// - 좌표/반경이 유효한 슬롯만 등록 대상으로 사용
  Future<void> _refreshSlots() async {
    try {
      final slotsResponse = await _notificationService.getGeofenceSlots();

      final regions = slotsResponse.slots
          .where((slot) => slot.active)
          .where((slot) => slot.latitude != null && slot.longitude != null)
          .where((slot) => slot.radiusM != null && slot.radiusM! > 0)
          .map((slot) => GeofenceRegion(
                id: 'slot_${slot.slotId}',
                latitude: slot.latitude!,
                longitude: slot.longitude!,
                radius: slot.radiusM!.toDouble(),
              ))
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

  /// 네이티브 geofence enter/exit 이벤트를 공통 이벤트로 변환해 처리합니다.
  Future<void> _handleTransition(GeofenceTransitionEvent transitionEvent) async {
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
      _logger.e('[GEOFENCE_PUBLISH_FAILED] ${event.geofenceId} $e');
    }
  }

  /// 네이티브에서 eventId를 주지 않을 때 사용할 fallback ID 생성기입니다.
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
