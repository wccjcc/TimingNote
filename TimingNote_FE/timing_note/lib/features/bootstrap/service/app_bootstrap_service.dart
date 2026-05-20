//부팅 유스케이스 조합
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/storage/device_identity_provider.dart';
import 'package:timing_note/core/storage/device_identity_store.dart';
import 'package:timing_note/features/bootstrap/service/device_registration_service.dart';
import 'package:uuid/uuid.dart';

class BootstrapResult {
  final String installationUuid;
  final String deviceSecret;
  final bool isNewRegistration;

  const BootstrapResult({
    required this.installationUuid,
    required this.deviceSecret,
    required this.isNewRegistration,
  });
}

class AppBootstrapService {
  final DeviceIdentityStore _store;
  final DeviceRegistrationService _registrationService;

  const AppBootstrapService(this._store, this._registrationService);

  Future<BootstrapResult> run() async {
    // 1) installationUuid 확보
    String? installationUuid = await _store.getInstallationUuid();
    var createdInstallationUuid = false;

    //installationUuid가 없을때의 로직
    if (installationUuid == null || installationUuid.isEmpty) {
      installationUuid = const Uuid().v4();
      await _store.saveInstallationUuid(installationUuid);
      createdInstallationUuid = true;
      // iOS Keychain 값은 앱 삭제 후에도 남을 수 있습니다.
      // 새 installationUuid를 만든 상태라면 이전 설치의 deviceSecret을 재사용하지 않고 재등록합니다.
      await _store.clearDeviceSecret();
    }

    // 2) 기존 deviceSecret 재사용
    final savedSecret = await _store.getDeviceSecret();
    if (!createdInstallationUuid &&
        savedSecret != null &&
        savedSecret.isNotEmpty) {
      return BootstrapResult(
        installationUuid: installationUuid,
        deviceSecret: savedSecret,
        isNewRegistration: false,
      );
    }

    // 3) 없으면 SYS-01 발급 요청 후 저장
    final registration = await _registrationService.register(
      installationUuid: installationUuid,
    );

    await _store.saveRegistration(
      deviceSecret: registration.deviceSecret,
      userId: registration.userId,
      createdAt: registration.createdAt,
    );

    return BootstrapResult(
      installationUuid: installationUuid,
      deviceSecret: registration.deviceSecret,
      isNewRegistration: true,
    );
  }
}

final appBootstrapServiceProvider = Provider<AppBootstrapService>((ref) {
  final store = ref.read(deviceIdentityStoreProvider);
  final registrationService = ref.read(deviceRegistrationServiceProvider);
  return AppBootstrapService(store, registrationService);
});
