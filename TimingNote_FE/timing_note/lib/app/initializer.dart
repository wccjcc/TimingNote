import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:permission_handler/permission_handler.dart';

import '../core/geofence/geofence_runtime.dart';
import '../core/location/location_permission_service.dart';
import '../core/location/location_service.dart';
import '../core/location/location_provider.dart';
import '../features/bootstrap/service/app_bootstrap_service.dart';
import '../features/mypage/service/user_settings_service.dart';

/// 앱 시작 시 필요한 사전 초기화 로직을 담당하는 유틸리티 클래스입니다.
/// main.dart의 가독성을 높이고 초기화 순서를 중앙 집중화합니다.
class AppInitializer {
  static const String _locationPermissionPromptRequestedKey =
      'location_permission_prompt_requested';

  static Future<ProviderContainer> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. 한국어 로케일 데이터 초기화 (캘린더 등에서 사용)
    await initializeDateFormatting('ko_KR', null);

    // 2. ProviderContainer 생성 (runApp 이전 비동기 초기화에 사용)
    final container = ProviderContainer();

    try {
      // 3. 기기 식별값 및 보안 비밀키 준비 (API 호출 기반)
      final bootstrapResult = await container
          .read(appBootstrapServiceProvider)
          .run();

      // 4. 최초 가입 시 기본 설정 등록 (SETTINGS-03)
      if (bootstrapResult.isNewRegistration) {
        try {
          await container
              .read(userSettingsServiceProvider)
              .registerSettings(
                locationAlertEnabled: true,
                pushAlertEnabled: true,
                radiusM: 300,
              );
        } catch (e) {
          debugPrint('[Initializer] SETTINGS-03 registration failed: $e');
        }
      }

      // 5. 네이티브 환경에서 지오펜스 런타임 사전 시작
      if (!kIsWeb) {
        try {
          await container.read(geofenceRuntimeProvider).start();
        } catch (e) {
          debugPrint('[Initializer] Geofence runtime start failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[Initializer] Critical bootstrap failed: $e');
    }

    // 6. GPS 웜업 및 최초 권한 안내 (UX 최적화)
    try {
      final perm = LocationPermissionService();
      final preferences = await SharedPreferences.getInstance();
      final alreadyPrompted =
          preferences.getBool(_locationPermissionPromptRequestedKey) ?? false;
      final whenInUseStatus = await perm.checkWhenInUse();

      // 최초 1회 OS 권한 팝업 자동 유도
      if (!alreadyPrompted && whenInUseStatus == PermissionStatus.denied) {
        await perm.requestWhenInUse();
        await preferences.setBool(_locationPermissionPromptRequestedKey, true);
      }
      
      // 위치 데이터 사전 조회 (캐시 확보)
      await container.read(locationServiceProvider).getCurrentPosition();
    } catch (e) {
      debugPrint('[Initializer] GPS warmup skipped: $e');
    }

    return container;
  }
}
