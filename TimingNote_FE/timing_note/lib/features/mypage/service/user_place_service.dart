import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_client.dart';
import 'package:timing_note/core/network/api_endpoints.dart';
import 'package:timing_note/core/network/api_exception.dart';
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
      return await _fetchUserPlaces();
    } catch (_) {
      return const [];
    }
  }

  /// 에러 발생 시 throw하는 strict 변형.
  /// 빈 응답과 네트워크 실패를 구분해야 하는 화면(MyPlacesScreen)에서 사용.
  Future<List<UserPlace>> getUserPlacesStrict() => _fetchUserPlaces();

  Future<List<UserPlace>> _fetchUserPlaces() async {
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
  }

  Future<UserPlace> createUserPlace({
    required String aliasName,
    String? kakaoPlaceId,
    required String placeName,
    required double latitude,
    required double longitude,
    String? addressName,
    String? roadAddressName,
    String? categoryGroupCode,
    String? categoryGroupName,
    String? phone,
    String? placeUrl,
  }) async {
    final body = <String, dynamic>{
      'aliasName': aliasName,
      if (kakaoPlaceId != null) 'kakaoPlaceId': kakaoPlaceId,
      'placeName': placeName,
      'latitude': latitude,
      'longitude': longitude,
      if (addressName != null) 'addressName': addressName,
      if (roadAddressName != null) 'roadAddressName': roadAddressName,
      if (categoryGroupCode != null) 'categoryGroupCode': categoryGroupCode,
      if (categoryGroupName != null) 'categoryGroupName': categoryGroupName,
      if (phone != null) 'phone': phone,
      if (placeUrl != null) 'placeUrl': placeUrl,
    };

    final envelope = await _client.post<UserPlace>(
      ApiEndpoints.userPlaces,
      data: body,
      dataParser: (json) =>
          UserPlace.fromJson(json as Map<String, dynamic>),
    );
    final data = envelope.data;
    if (data == null) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '내 장소 등록 응답에 data가 없습니다.',
      );
    }
    return data;
  }

  Future<UserPlace> updateUserPlace({
    required int userPlaceId,
    required String aliasName,
  }) async {
    final envelope = await _client.patch<UserPlace>(
      '${ApiEndpoints.userPlaces}/$userPlaceId',
      data: {'aliasName': aliasName},
      dataParser: (json) =>
          UserPlace.fromJson(json as Map<String, dynamic>),
    );
    final data = envelope.data;
    if (data == null) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '별칭 수정 응답에 data가 없습니다.',
      );
    }
    return data;
  }

  Future<void> deleteUserPlace(int userPlaceId) async {
    await _client.delete<void>('${ApiEndpoints.userPlaces}/$userPlaceId');
  }
}
