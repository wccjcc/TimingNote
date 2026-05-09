import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_provider.dart';
import '../model/todo_search_item.dart';

final todoSearchServiceProvider = Provider<TodoSearchService>((ref) {
  return TodoSearchService(apiClient: ref.read(apiClientProvider));
});

/// `GET /api/v1/todos/search` 호출 전용 서비스.
///
/// 응답 파싱은 [TodoSearchResult.fromJson]에 위임.
/// 인증(X-Device-Secret) / 로깅 / 에러 매핑은 [ApiClient] 인터셉터가 처리.
class TodoSearchService {
  TodoSearchService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// 본문 검색.
  ///
  /// - [q]: 검색어 (필수, BE에서 빈 문자열 시 400)
  /// - [status]: 미입력 시 BE 기본값 ACTIVE. 완료 항목까지 보려면 'DONE' 명시
  /// - [category], [todoType]: 옵션 필터
  /// - [cursor]: 무한 스크롤용 (이전 응답의 nextCursor)
  /// - [size]: 페이지 크기 (1~50, BE 기본 20)
  Future<TodoSearchResult> search({
    required String q,
    String? status,
    String? category,
    String? todoType,
    String? cursor,
    int? size,
  }) async {
    final queryParams = <String, dynamic>{
      'q': q,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (todoType != null) 'todoType': todoType,
      if (cursor != null) 'cursor': cursor,
      if (size != null) 'size': size,
    };

    final envelope = await _client.get<TodoSearchResult>(
      '${ApiEndpoints.todos}/search',
      queryParameters: queryParams,
      dataParser: (json) =>
          TodoSearchResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
