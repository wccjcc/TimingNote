import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}