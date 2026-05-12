import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_provider.dart';
import '../model/selected_kakao_place.dart';

/// 장소 검색/역지오코딩 서비스.
///
/// 이전: FE에서 카카오 REST API(`dapi.kakao.com`)를 직접 호출 (REST key 노출 문제).
/// 현재: BE 프록시(`/api/v1/places/*`)를 통한 호출. 카카오 키는 BE 환경변수로 격리되고,
///       카카오 개발자센터에서 BE 서버 IP를 허용 IP로 등록해 키 탈취 시도를 차단한다.
///       X-Device-Secret은 ApiClient의 interceptor가 자동 주입.
class PlaceSearchService {
  PlaceSearchService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// 키워드로 장소 검색.
  /// [lat], [lng] 제공 시 거리순 정렬(반경 20km), 미제공 시 정확도순.
  Future<List<KakaoPlaceItem>> searchKeyword(
    String query, {
    double? lat,
    double? lng,
    int size = 15,
  }) async {
    if (query.trim().isEmpty) return [];

    final envelope = await _client.get<List<KakaoPlaceItem>>(
      ApiEndpoints.placesSearch,
      queryParameters: {
        'query': query.trim(),
        'size': size,
        'lat': ?lat,
        'lng': ?lng,
      },
      dataParser: (json) => (json as List<dynamic>)
          .map((e) => KakaoPlaceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return envelope.data ?? const [];
  }

  /// 좌표 → 도로명/지번 주소 (지도 핀 드래그 시 역지오코딩).
  Future<String?> reverseGeocode(double lat, double lng) async {
    final envelope = await _client.get<String?>(
      ApiEndpoints.placesReverseGeocode,
      queryParameters: {'lat': lat, 'lng': lng},
      dataParser: (json) {
        final map = json as Map<String, dynamic>;
        return map['address'] as String?;
      },
    );
    return envelope.data;
  }
}

final placeSearchServiceProvider = Provider<PlaceSearchService>(
  (ref) => PlaceSearchService(apiClient: ref.read(apiClientProvider)),
);
