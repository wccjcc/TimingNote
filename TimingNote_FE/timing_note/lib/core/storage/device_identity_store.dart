import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  final String installationUuid;
  final String? deviceSecret;
  final int? userId;
  final String? createdAt;

  const DeviceIdentity({
    required this.installationUuid,
    this.deviceSecret,
    this.userId,
    this.createdAt,
  });
}

class DeviceIdentityStore {
  static const _kInstallationUuid = 'installation_uuid';
  static const _kDeviceSecretSecure = 'device_secret';
  static const _kDeviceSecretLegacy = 'device_secret';
  static const _kUserId = 'user_id';
  static const _kCreatedAt = 'user_created_at';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> getInstallationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kInstallationUuid);
  }

  Future<void> saveInstallationUuid(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstallationUuid, uuid);
  }

  Future<String?> getDeviceSecret() async {
    // 1) secure storage 우선 조회
    try {
      final secureSecret = await _secureStorage.read(key: _kDeviceSecretSecure);
      if (secureSecret != null && secureSecret.isNotEmpty) {
        return secureSecret;
      }
    } catch (_) {
      // 웹/환경 제약으로 secure storage 접근 실패 가능
    }

    // 2) fallback(shared_preferences) 조회
    final prefs = await SharedPreferences.getInstance();
    final legacySecret = prefs.getString(_kDeviceSecretLegacy);
    if (legacySecret != null && legacySecret.isNotEmpty) {
      // 가능한 경우 secure storage로 재마이그레이션
      try {
        await _secureStorage.write(
          key: _kDeviceSecretSecure,
          value: legacySecret,
        );
      } catch (_) {
        // secure 저장 실패 시 무시 (legacy 값으로 계속 동작)
      }
      return legacySecret;
    }

    return null;
  }

  Future<void> saveDeviceSecret(String deviceSecret) async {
    // secure storage 저장 시도
    try {
      await _secureStorage.write(
        key: _kDeviceSecretSecure,
        value: deviceSecret,
      );
    } catch (_) {
      // 실패 시 fallback 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDeviceSecretLegacy, deviceSecret);
    }
  }

  Future<void> saveRegistration({
    required String deviceSecret,
    required int userId,
    required String createdAt,
  }) async {
    // secret 저장
    try {
      await _secureStorage.write(
        key: _kDeviceSecretSecure,
        value: deviceSecret,
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDeviceSecretLegacy, deviceSecret);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kCreatedAt, createdAt);
  }

  Future<DeviceIdentity?> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final installationUuid = prefs.getString(_kInstallationUuid);
    if (installationUuid == null) return null;

    final deviceSecret = await getDeviceSecret();

    return DeviceIdentity(
      installationUuid: installationUuid,
      deviceSecret: deviceSecret,
      userId: prefs.getInt(_kUserId),
      createdAt: prefs.getString(_kCreatedAt),
    );
  }

  Future<void> clearDeviceSecret() async {
    try {
      await _secureStorage.delete(key: _kDeviceSecretSecure);
    } catch (_) {
      // ignore
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeviceSecretLegacy);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kInstallationUuid);
    await prefs.remove(_kUserId);
    await prefs.remove(_kCreatedAt);
    await prefs.remove(_kDeviceSecretLegacy);

    try {
      await _secureStorage.delete(key: _kDeviceSecretSecure);
    } catch (_) {
      // ignore
    }
  }
}
