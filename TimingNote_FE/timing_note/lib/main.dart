import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:timing_note/core/geofence/geofence_runtime.dart';
import 'package:timing_note/core/notification/local_notification_service.dart';
import 'package:timing_note/features/bootstrap/service/app_bootstrap_service.dart';

import 'app/app.dart';

final _logger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 로컬 알림 플러그인을 앱 시작 전에 초기화합니다.
  final localNotificationService = LocalNotificationService();
  await localNotificationService.initialize();

  // 앱 전역 ProviderContainer를 직접 생성해 runApp 이전 초기화에 사용합니다.
  final container = ProviderContainer();

  try {
    // 1) installationUuid / deviceSecret 준비
    // - 신규 설치면 /users 등록 API 호출로 secret 발급
    // - 기존 설치면 저장된 secret 재사용(또는 재발급 정책 반영)
    await container.read(appBootstrapServiceProvider).run();

    // 2) Device Secret 준비 완료 후 geofence 런타임 시작
    // - SSE 구독 및 슬롯 동기화 파이프라인의 진입점입니다.
    // - 실패해도 앱 기동은 유지하고, 런타임 기능만 추후 재시도 가능하게 둡니다.
    try {
      await container.read(geofenceRuntimeProvider).start();
    } catch (e, st) {
      _logger.e('Geofence runtime start failed', error: e, stackTrace: st);
    }
  } catch (e, st) {
    // 부트스트랩 실패 시에도 앱은 띄워서 사용자에게 최소 UI를 제공합니다.
    _logger.e('Bootstrap failed', error: e, stackTrace: st);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
