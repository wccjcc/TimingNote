import 'dart:async';

import 'package:flutter/services.dart';

/// iOS 네이티브(AppDelegate)에서 전달한 푸시 액션 탭 이벤트를 수신하는 브리지입니다.
///
/// 채널 규약:
/// - channel: timing_note/push_actions
/// - method : onPushAction
/// - args   : { actionId, notificationId, todoId, slotId }
class PushActionBridge {
  PushActionBridge();

  static const MethodChannel _channel = MethodChannel('timing_note/push_actions');

  final StreamController<Map<String, String>> _eventsController =
      StreamController<Map<String, String>>.broadcast();

  bool _initialized = false;

  Stream<Map<String, String>> get events => _eventsController.stream;

  /// 네이티브 메서드 콜 핸들러를 1회 등록합니다.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onPushAction') {
        return;
      }

      final args = call.arguments;
      if (args is! Map) {
        return;
      }

      final payload = <String, String>{
        'actionId': (args['actionId'] ?? '').toString(),
        'notificationId': (args['notificationId'] ?? '').toString(),
        'todoId': (args['todoId'] ?? '').toString(),
        'slotId': (args['slotId'] ?? '').toString(),
      };
      _eventsController.add(payload);
    });

    _initialized = true;
  }
}
