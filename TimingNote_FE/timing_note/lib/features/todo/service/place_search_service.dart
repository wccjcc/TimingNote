import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/kakao_config.dart';
import '../model/selected_kakao_place.dart';

class PlaceSearchService {
  PlaceSearchService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://dapi.kakao.com',
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            headers: {
              'Authorization': 'KakaoAK ${KakaoConfig.restApiKey}',
            },
          ),
        );

  final Dio _dio;

  /// 키워드로 장소 검색.
  /// [lat], [lng] 제공 시 거리순 정렬, 미제공 시 정확도순.
  Future<List<KakaoPlaceItem>> searchKeyword(
    String query, {
    double? lat,
    double? lng,
    int size = 15,
  }) async {
    if (query.trim().isEmpty) return [];

    final params = <String, dynamic>{
      'query': query.trim(),
      'size': size,
      if (lat != null && lng != null) ...{
        'y': lat.toString(),
        'x': lng.toString(),
        'sort': 'distance',
        'radius': 20000,
      },
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/local/search/keyword.json',
      queryParameters: params,
    );

    final documents = response.data?['documents'] as List<dynamic>? ?? [];
    return documents
        .map((e) => KakaoPlaceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 좌표 → 도로명/지번 주소 (지도 핀 드래그 시 역지오코딩).
  Future<String?> reverseGeocode(double lat, double lng) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/local/geo/coord2address.json',
      queryParameters: {'x': lng.toString(), 'y': lat.toString()},
    );

    final documents = response.data?['documents'] as List<dynamic>? ?? [];
    if (documents.isEmpty) return null;

    final first = documents.first as Map<String, dynamic>;
    final road = first['road_address'] as Map<String, dynamic>?;
    final jibun = first['address'] as Map<String, dynamic>?;
    return road?['address_name'] as String? ??
        jibun?['address_name'] as String?;
  }
}

final placeSearchServiceProvider = Provider<PlaceSearchService>(
  (_) => PlaceSearchService(),
);
