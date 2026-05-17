import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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
    int radiusM = 500,
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
        : '?�재 ?�치';

    final items = rawItems
        .expand((e) => _parseGroupItems(e as Map<String, dynamic>))
        .toList();

    debugPrint('[RECO] raw groups: ${rawItems.length}');
    debugPrint('[RECO] parsed items: ${items.length}');
    if (rawItems.isNotEmpty) {
      debugPrint('[RECO] first group keys: ${(rawItems.first as Map<String, dynamic>).keys.toList()}');
    }

    return HomeRecommendationResult(
      currentLocationLabel: label,
      items: items,
    );
  }

  List<HomeRecommendationItem> _parseGroupItems(Map<String, dynamic> json) {
    final groupId = (json['groupId'] as num?)?.toInt();
    final rank = (json['rank'] as num?)?.toInt() ?? 0;
    final todoCount = (json['todoCount'] as num?)?.toInt() ?? 0;
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    if (groupId == null || lat == null || lng == null) {
      debugPrint('[RECO] skip group: invalid group fields '
          'groupId=$groupId lat=$lat lng=$lng raw=$json');
      return const <HomeRecommendationItem>[];
    }

    final placeName = (json['placeName'] as String?)?.trim();
    final distanceMeters = (json['distanceM'] as num?)?.toDouble() ?? 0;
    final rawTodos = (json['todos'] as List<dynamic>? ?? const []);

    final parsed = rawTodos.map((todoRaw) {
      final todoJson = todoRaw as Map<String, dynamic>;
      final todoId = (todoJson['todoId'] as num?)?.toInt();
      if (todoId == null) {
        debugPrint('[RECO] skip todo: invalid todoId raw=$todoJson');
        return null;
      }

      final category = (todoJson['category'] as String?) ?? TodoCategory.etc;
      final todoType = (todoJson['todoType'] as String?) ?? TodoType.general;
      final title =
          ((todoJson['summaryText'] as String?) ?? '').trim().isNotEmpty
          ? (todoJson['summaryText'] as String).trim()
          : '추천 할일';

      final resolvedPlace = (todoJson['resolvedPlaceLabel'] as String?)?.trim();
      // 내 장소(ALIAS)는 서버의 resolvedPlaceLabel에 사용자가 저장한 aliasName이 들어온다.
      // 특정 장소의 주소 라벨과 섞이지 않도록 ALIAS일 때만 이 값을 카드 위치명으로 우선 사용한다.
      final aliasPlace =
          todoType == TodoType.alias && resolvedPlace?.isNotEmpty == true
          ? resolvedPlace
          : null;
      final fallbackPlace = placeName?.isNotEmpty == true
          ? placeName
          : (resolvedPlace?.isNotEmpty == true ? resolvedPlace : null);
      final place = aliasPlace ?? fallbackPlace ?? '주변 장소';

      return HomeRecommendationItem(
        groupId: groupId,
        todoId: todoId,
        rank: rank,
        todoCount: todoCount,
        category: category,
        todoType: todoType,
        title: title,
        place: place,
        distanceMeters: distanceMeters,
        placeLat: lat,
        placeLng: lng,
      );
    }).whereType<HomeRecommendationItem>().toList();
    debugPrint('[RECO] group=$groupId todos(raw=${rawTodos.length}, parsed=${parsed.length})');
    return parsed;
  }
}
