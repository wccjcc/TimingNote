import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_identity_store.dart';

// 앱 전역에서 동일한 저장소 인스턴스를 읽기 위한 Provider
final deviceIdentityStoreProvider = Provider<DeviceIdentityStore>((ref) {
  return DeviceIdentityStore();
});
