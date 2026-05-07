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
    final envelope = await _client.get<List<UserPlace>>(
      ApiEndpoints.userPlaces,
      dataParser: (json) {
        final list = (json as List<dynamic>)
            .map((item) => UserPlace.fromJson(item as Map<String, dynamic>))
            .toList();
        return list;
      },
    );

    return envelope.data ?? const [];
  }

  Future<void> deleteUserPlace(int userPlaceId) async {
    await _client.delete<void>('${ApiEndpoints.userPlaces}/$userPlaceId');
  }
}
