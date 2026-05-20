import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/device_identity_store.dart';
import 'api_client.dart';

// 환경값(나중에 dev/prod 분리 가능)
// 안드로이드 에뮬레이터: 10.0.2.2 (PC의 localhost)
// 실기기/iOS 시뮬레이터: PC의 실제 IP (예: 192.168.0.x) : 와이파이가 같아야함
// 배포 서버: https://api.timingnote.com/api/v1
// const String apiBaseUrl = 'https://api.timingnote.co.kr/api/v1';
const String apiBaseUrl = 'http://localhost:8080/api/v1';
// const String apiBaseUrl = 'http://127.0.0.1:8080/api/v1';
// ApiClient를 생성해서 앱에서 ref.read/watch로 가져다 쓸 수 있음
final apiClientProvider = Provider<ApiClient>((ref) {
  final store = DeviceIdentityStore();

  return ApiClient(
    baseUrl: apiBaseUrl,
    readDeviceSecret: () async {
      return store.getDeviceSecret();
    },
  );
});
