import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_provider.dart';
import 'package:timing_note/features/mypage/model/user_place.dart';

final userPlaceServiceProvider = Provider<UserPlaceService>((ref) {
  return UserPlaceService(apiClient: ref.read(apiClientProvider));
});

class UserPlaceService {
  UserPlaceService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<List<UserPlace>> getUserPlaces() async {
    // BE/FE 미연결 또는 응답 형식 불일치 시 빈 리스트 fallback — 호출처가 항상 안전.
    try {
      final envelope = await _client.get<List<UserPlace>>(
        ApiEndpoints.userPlaces,
        dataParser: (json) {
          if (json is! List) return <UserPlace>[];
          return json
              .whereType<Map<String, dynamic>>()
              .map((item) {
                try {
                  return UserPlace.fromJson(item);
                } catch (_) {
                  return null;
                }
              })
              .whereType<UserPlace>()
              .toList();
        },
      );
      return envelope.data ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> deleteUserPlace(int userPlaceId) async {
    await _client.delete<void>('${ApiEndpoints.userPlaces}/$userPlaceId');
  }
}
