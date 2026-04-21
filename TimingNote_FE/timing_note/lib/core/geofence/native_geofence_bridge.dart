import 'dart:async';

import 'package:flutter/services.dart';

/// 네이티브(Android/iOS) geofence 모듈과 통신하는 브리지
///
/// 채널 구성
/// - MethodChannel: 등록/해제 같은 "명령" 전달
/// - EventChannel: 네이티브에서 발생한 enter/exit 이벤트를 실시간 수신
class NativeGeofenceBridge {
  NativeGeofenceBridge();

  static const MethodChannel _methodChannel =
      MethodChannel('timing_note/geofence_method');
  static const EventChannel _eventChannel =
      EventChannel('timing_note/geofence_events');

  /// 네이티브에 geofence 목록 등록 요청
  Future<void> registerGeofences(List<Map<String, dynamic>> regions) async {
    await _methodChannel.invokeMethod<void>(
      'registerGeofences',
      {'regions': regions},
    );
  }

  /// 네이티브 geofence 모니터링 전체 해제
  Future<void> clearGeofences() async {
    await _methodChannel.invokeMethod<void>('clearGeofences');
  }

  /// 네이티브가 발생시킨 이벤트 스트림
  ///
  /// 이벤트 포맷 예시
  /// {
  ///   eventId: "...",
  ///   geofenceId: "...",
  ///   transition: "ENTER" | "EXIT",
  ///   occurredAt: "2026-04-21T10:20:30.000Z",
  ///   latitude: 37.123,
  ///   longitude: 127.123,
  ///   accuracyMeters: 15.0
  /// }
  Stream<Map<String, dynamic>> get events {
    return _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => Map<String, dynamic>.from(event as Map));
  }
}
