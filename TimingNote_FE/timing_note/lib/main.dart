import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_note/core/geofence/geofence_runtime.dart';
import 'package:timing_note/core/location/location_permission_service.dart';
import 'package:timing_note/core/location/location_provider.dart';
import 'package:timing_note/features/bootstrap/service/app_bootstrap_service.dart';
import 'package:timing_note/features/mypage/service/user_settings_service.dart';

import 'app/app.dart';

final _logger = Logger();
const String _locationPermissionPromptRequestedKey =
    'location_permission_prompt_requested';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // intl의 한국어 locale data 초기화 — table_calendar의 `locale: 'ko_KR'`이
  // 월/요일 라벨을 한글로 표시하는 데 사용한다.
  await initializeDateFormatting('ko_KR', null);

  // 앱 전역 ProviderContainer를 직접 생성해 runApp 이전 초기화에 사용합니다.
  final container = ProviderContainer();

  try {
    // 1) installationUuid / deviceSecret 준비
    final bootstrapResult = await container
        .read(appBootstrapServiceProvider)
        .run();

    // 1-1) 신규 디바이스 등록 직후 SETTINGS-03 기본 설정을 1회 생성한다.
    if (bootstrapResult.isNewRegistration) {
      try {
        await container
            .read(userSettingsServiceProvider)
            .registerSettings(
              locationAlertEnabled: true,
              pushAlertEnabled: true,
              radiusM: 300,
            );
      } catch (e, st) {
        _logger.w('SETTINGS-03 register failed', error: e, stackTrace: st);
      }
    }

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
    final preferences = await SharedPreferences.getInstance();
    final alreadyPrompted =
        preferences.getBool(_locationPermissionPromptRequestedKey) ?? false;
    final whenInUseStatus = await perm.checkWhenInUse();

    // 아직 권한 결정을 하지 않은(최초) 상태에서만 OS 권한 팝업을 자동 요청한다.
    if (!alreadyPrompted && whenInUseStatus.isDenied) {
      await perm.requestWhenInUse();
      await preferences.setBool(_locationPermissionPromptRequestedKey, true);
    }
    await container.read(locationServiceProvider).getCurrentPosition();
  } catch (_) {
    // 권한 거부 또는 GPS 실패 — 이후 사용처에서 재시도
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
