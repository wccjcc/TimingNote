import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/app/initializer.dart';

import 'app/app.dart';

Future<void> main() async {
  // 앱 전역 ProviderContainer를 AppInitializer를 통해 생성 및 초기화합니다.
  final container = await AppInitializer.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
