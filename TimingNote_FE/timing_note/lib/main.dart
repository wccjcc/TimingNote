import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/notification/local_notification_service.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //local 알림 초기화 
  final localNotificationService = LocalNotificationService();
  await localNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}