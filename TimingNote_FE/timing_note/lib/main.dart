import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:timing_note/core/geofence/geofence_runtime.dart';
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
