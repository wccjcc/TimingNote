import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/location/location_permission_service.dart';
import 'package:timing_note/core/location/location_provider.dart';
import 'package:timing_note/core/notification/local_notification_service.dart';
import 'package:timing_note/features/bootstrap/service/app_bootstrap_service.dart';
import 'package:logger/logger.dart';

import 'app/app.dart';

final _logger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //local 알림 초기화 
  final localNotificationService = LocalNotificationService();
  await localNotificationService.initialize();

  //ProviderContainer를 먼저 만들고 부팅 서비스 진행
  final container = ProviderContainer();

  try {
    // 앱 시작 시 백그라운드에서 device identity 확보
    await container.read(appBootstrapServiceProvider).run();
  } catch (e,st) {
    // 실패해도 앱은 일단 실행
    _logger.e('Bootstrap Failed',error: e, stackTrace: st);
  }

  // GPS warmup — 첫 실행 시 권한 dialog 유도 + 시스템 위치 서비스 준비.
  // 결과는 캐싱하지 않고 버린다 (모든 사용처는 호출 시점에 GPS 직접 조회).
  try {
    final perm = LocationPermissionService();
    if (!await perm.isWhenInUseGranted()) {
      await perm.requestWhenInUse();
    }
    await container.read(locationServiceProvider).getCurrentPosition();
  } catch (_) {
    // 권한 거부 또는 GPS 실패 — 이후 사용처에서 재시도
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}