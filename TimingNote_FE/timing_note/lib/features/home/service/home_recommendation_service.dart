import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_provider.dart';
import '../../todo/model/todo.dart';
import '../model/home_recommendation.dart';

final homeRecommendationServiceProvider = Provider<HomeRecommendationService>((
  ref,
) {
  return HomeRecommendationService(apiClient: ref.read(apiClientProvider));
});

class HomeRecommendationService {
  HomeRecommendationService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<HomeRecommendationResult> getRecommendations({
    required double latitude,
    required double longitude,
    double? course,
    int radiusM = 300,
    String triggerType = 'HOME_ENTER',
  }) async {
    final envelope = await _client.get<HomeRecommendationResult>(
      ApiEndpoints.recommendations,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusM': radiusM,
        'triggerType': triggerType,
        if (course != null) 'course': course,
      },
      dataParser: (json) => _parseRecommendationResult(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  HomeRecommendationResult _parseRecommendationResult(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    final label =
        (json['currentLocationLabel'] as String?)?.trim().isNotEmpty == true
        ? (json['currentLocationLabel'] as String).trim()
        : '현재 위치';

    final items = rawItems
        .map((e) => _parseItem(e as Map<String, dynamic>))
        .whereType<HomeRecommendationItem>()
        .toList();

    return HomeRecommendationResult(
      currentLocationLabel: label,
      items: items,
    );
  }

  HomeRecommendationItem? _parseItem(Map<String, dynamic> json) {
    final todoId = json['todoId'] as int?;
    if (todoId == null) return null;

    final category = (json['category'] as String?) ?? TodoCategory.etc;
    final title =
        ((json['summaryText'] as String?) ?? '').trim().isNotEmpty
        ? (json['summaryText'] as String).trim()
        : '추천 할일';

    final resolvedPlace = (json['resolvedPlaceLabel'] as String?)?.trim();
    final placeName = (json['placeName'] as String?)?.trim();
    final place = (resolvedPlace?.isNotEmpty == true
            ? resolvedPlace
            : (placeName?.isNotEmpty == true ? placeName : null)) ??
        '주변 장소';

    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return HomeRecommendationItem(
      todoId: todoId,
      category: category,
      title: title,
      place: place,
      distanceMeters: (json['distanceM'] as num?)?.toDouble() ?? 0,
      placeLat: lat,
      placeLng: lng,
    );
  }
}
