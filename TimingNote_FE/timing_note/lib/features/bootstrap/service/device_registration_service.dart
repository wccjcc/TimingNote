import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_exception.dart';
import 'package:timing_note/core/network/api_provider.dart';

//device 등록 서비스(SYS-01 API 호출 전담)

class DeviceRegistrationResponse {
  final int userId;
  final String deviceSecret;
  final String createdAt;

  const DeviceRegistrationResponse({
    required this.userId,
    required this.deviceSecret,
    required this.createdAt,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResponse(
      userId: (json['userId'] as num).toInt(),
      deviceSecret: json['deviceSecret'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class DeviceRegistrationService {
  final ApiClient _apiClient;

  const DeviceRegistrationService(this._apiClient);

  Future<DeviceRegistrationResponse> register({
    required String installationUuid,
  }) async {
    final envelope = await _apiClient.post<DeviceRegistrationResponse>(
      ApiEndpoints.sys01,
      data: {
        'installationUuid': installationUuid,
      },
      // SYS-01은 최초 발급 API라 X-Device-Secret 헤더 제외
      skipDeviceSecret: true,
      dataParser: (json) => DeviceRegistrationResponse.fromJson(
        json as Map<String, dynamic>,
      ),
    );

    final data = envelope.data;
    if (data == null) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'SYS-01 응답 data가 비어 있습니다.',
      );
    }

    return data;
  }
}

final deviceRegistrationServiceProvider = Provider<DeviceRegistrationService>(
  (ref) {
    final apiClient = ref.read(apiClientProvider);
    return DeviceRegistrationService(apiClient);
  },
);
