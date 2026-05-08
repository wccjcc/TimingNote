import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:timing_note/core/geofence/geofence_runtime.dart';
import 'package:timing_note/core/location/location_permission_service.dart';
import 'package:timing_note/core/location/location_provider.dart';
import 'package:timing_note/features/bootstrap/service/app_bootstrap_service.dart';

import 'app/app.dart';

final _logger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 전역 ProviderContainer를 직접 생성해 runApp 이전 초기화에 사용합니다.
  final container = ProviderContainer();

  try {
    // 1) installationUuid / deviceSecret 준비
    await container.read(appBootstrapServiceProvider).run();

    // 2) 모바일(iOS/Android)에서만 geofence 런타임 사전 시작을 시도합니다.
    // - 웹에서는 브라우저 제약으로 초기 진입 지연이 커질 수 있어 제외합니다.
    if (!kIsWeb) {
      try {
        await container.read(geofenceRuntimeProvider).start();
      } catch (e, st) {
        _logger.e('Geofence runtime start failed', error: e, stackTrace: st);
      }
    }
  } catch (e, st) {
    // 부트스트랩 실패 시에도 앱은 띄워서 사용자에게 최소 UI를 제공합니다.
    _logger.e('Bootstrap failed', error: e, stackTrace: st);
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
