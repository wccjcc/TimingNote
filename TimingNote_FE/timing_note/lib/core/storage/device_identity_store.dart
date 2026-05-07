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
  static const _kDeviceSecretLegacy = 'device_secret'; // shared_preferences 레거시 키
  static const _kUserId = 'user_id';
  static const _kCreatedAt = 'user_created_at';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(); //flutter_secure_storage에 저장

  Future<String?> getInstallationUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kInstallationUuid);
  }

  Future<void> saveInstallationUuid(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstallationUuid, uuid);
  }

  Future<String?> getDeviceSecret() async {
    // 1) 우선 secure storage에서 조회
    final secureSecret = await _secureStorage.read(key: _kDeviceSecretSecure);
    if (secureSecret != null && secureSecret.isNotEmpty) {
      return secureSecret;
    }

    // 2) 레거시(shared_preferences) 값이 있으면 1회 마이그레이션
    final prefs = await SharedPreferences.getInstance();
    final legacySecret = prefs.getString(_kDeviceSecretLegacy);
    if (legacySecret != null && legacySecret.isNotEmpty) {
      await _secureStorage.write(
        key: _kDeviceSecretSecure,
        value: legacySecret,
      );
      await prefs.remove(_kDeviceSecretLegacy);
      return legacySecret;
    }

    return null;
  }

  Future<void> saveDeviceSecret(String deviceSecret) async {
    //flutter_secure_storage에 device secret 저장 
    await _secureStorage.write(
      key: _kDeviceSecretSecure,
      value: deviceSecret,
    );
  }

  Future<void> saveRegistration({
    required String deviceSecret,
    required int userId,
    required String createdAt,
  }) async {
    // 민감정보는 secure storage에 저장
    await _secureStorage.write(
      key: _kDeviceSecretSecure,
      value: deviceSecret,
    );

    // 일반 메타정보는 shared_preferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kCreatedAt, createdAt);

    // 혹시 남아 있을 수 있는 레거시 secret 정리
    await prefs.remove(_kDeviceSecretLegacy);
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
    await _secureStorage.delete(key: _kDeviceSecretSecure);

    // 레거시 키도 같이 정리
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeviceSecretLegacy);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kInstallationUuid);
    await prefs.remove(_kUserId);
    await prefs.remove(_kCreatedAt);
    await prefs.remove(_kDeviceSecretLegacy);

    await _secureStorage.delete(key: _kDeviceSecretSecure);
  }
}
