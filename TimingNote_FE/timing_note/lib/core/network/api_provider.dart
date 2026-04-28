import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/device_auth_storage.dart';
import 'api_client.dart';

// 환경값(나중에 dev/prod 분리 가능)
const String _baseUrl = 'http://localhost:8080/api';

// ApiClient를 생성해서 앱에서 ref.read/watch로 가져다 쓸 수 있음
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _baseUrl,
    readDeviceSecret: () async {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(deviceSecretStorageKey);
    },
  );
});
