import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_provider.dart';
import 'package:timing_note/features/mypage/model/user_settings.dart';

final userSettingsServiceProvider = Provider<UserSettingsService>((ref) {
  return UserSettingsService(apiClient: ref.read(apiClientProvider));
});

class UserSettingsService {
  UserSettingsService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<UserSettings> getSettings() async {
    final envelope = await _client.get<UserSettings>(
      ApiEndpoints.userSettings,
      dataParser: (json) => UserSettings.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<UserSettings> updateSettings({
    bool? locationAlertEnabled,
    bool? pushAlertEnabled,
    int? radiusM,
  }) async {
    final body = <String, dynamic>{
      if (locationAlertEnabled != null)
        'locationAlertEnabled': locationAlertEnabled,
      if (pushAlertEnabled != null) 'pushAlertEnabled': pushAlertEnabled,
      if (radiusM != null) 'radiusM': radiusM,
    };

    final envelope = await _client.patch<UserSettings>(
      ApiEndpoints.userSettings,
      data: body,
      dataParser: (json) => UserSettings.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
