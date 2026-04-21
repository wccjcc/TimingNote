import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

// 환경값(나중에 dev/prod 분리 가능)
const String _baseUrl = 'http://localhost:8080/api';
const String _deviceSecret = 'TEMP_DEVICE_SECRET';

// ApiClient를 생성해서 앱에서 ref.read/watch로 가져다 쓸 수 있음
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _baseUrl,
    deviceSecret: _deviceSecret,
  );
});
