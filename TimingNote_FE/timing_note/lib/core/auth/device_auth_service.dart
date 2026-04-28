import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_exception.dart';
import '../network/api_provider.dart';
import 'device_auth_storage.dart';

final deviceAuthServiceProvider = Provider<DeviceAuthService>((ref) {
  return DeviceAuthService(
    apiClient: ref.read(apiClientProvider),
  );
});

/// 디바이스 최초 등록과 deviceSecret 저장을 담당하는 서비스
class DeviceAuthService {
  DeviceAuthService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Logger _logger = Logger();

  /// 앱 시작 시 1회 호출해서 deviceSecret이 없으면 발급받아 저장한다.
  Future<void> initialize() async {
    await ensureDeviceSecret();
  }

  /// 저장된 deviceSecret이 있으면 재사용하고, 없으면 SYS-01 등록 API를 호출한다.
  Future<String> ensureDeviceSecret() async {
    final preferences = await SharedPreferences.getInstance();
    final storedDeviceSecret = preferences.getString(deviceSecretStorageKey);
    if (_hasText(storedDeviceSecret)) {
      return storedDeviceSecret!;
    }

    final installationUuid =
        await _ensureInstallationUuid(preferences: preferences);

    return _registerDevice(
      preferences: preferences,
      installationUuid: installationUuid,
      canRecoverUuidConflict: true,
    );
  }

  Future<String?> readStoredDeviceSecret() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(deviceSecretStorageKey);
  }

  Future<String> _ensureInstallationUuid({
    required SharedPreferences preferences,
  }) async {
    final storedUuid = preferences.getString(installationUuidStorageKey);
    if (_hasText(storedUuid)) {
      return storedUuid!;
    }

    final installationUuid = _generateUuidV4();
    await preferences.setString(
      installationUuidStorageKey,
      installationUuid,
    );
    return installationUuid;
  }

  /// 백엔드가 installationUuid 중복을 돌려주면, 로컬 상태 유실로 보고 UUID를 1회 재생성해 복구한다.
  Future<String> _registerDevice({
    required SharedPreferences preferences,
    required String installationUuid,
    required bool canRecoverUuidConflict,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.users,
        data: {
          'installationUuid': installationUuid,
        },
        skipDeviceSecret: true,
        dataParser: (json) => Map<String, dynamic>.from(json as Map),
      );

      final data = response.data;
      final deviceSecret = data?['deviceSecret']?.toString();
      if (!_hasText(deviceSecret)) {
        throw const ApiException(
          code: 'INVALID_DEVICE_SECRET',
          message: '디바이스 등록 응답에 deviceSecret이 없습니다.',
        );
      }

      await preferences.setString(deviceSecretStorageKey, deviceSecret!);
      _logger.i('디바이스 등록 완료: installationUuid=$installationUuid');
      return deviceSecret;
    } on ApiException catch (error) {
      if (error.code == 'COMMON-409-1' && canRecoverUuidConflict) {
        final recoveredUuid = _generateUuidV4();
        await preferences.setString(
          installationUuidStorageKey,
          recoveredUuid,
        );

        _logger.w('기존 installationUuid가 충돌하여 새 UUID로 1회 재시도합니다.');

        return _registerDevice(
          preferences: preferences,
          installationUuid: recoveredUuid,
          canRecoverUuidConflict: false,
        );
      }

      rethrow;
    }
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// 외부 패키지 없이 RFC 4122 형식의 UUID v4 문자열을 생성한다.
  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();

    return [
      value.substring(0, 8),
      value.substring(8, 12),
      value.substring(12, 16),
      value.substring(16, 20),
      value.substring(20, 32),
    ].join('-');
  }
}
