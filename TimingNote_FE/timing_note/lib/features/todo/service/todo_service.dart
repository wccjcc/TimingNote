import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_provider.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../model/todo_detail.dart';

final todoServiceProvider = Provider<TodoService>((ref) {
  return TodoService(apiClient: ref.read(apiClientProvider));
});

class TodoService {
  TodoService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  // ── 목록 조회 ────────────────────────────────────────────────────
  // status: ACTIVE | DONE (미입력 시 DELETED 제외 전체)
  // tab: DINE | ACQUIRE | HEALTH | SERVICE | ...
  // placeType: SPECIFIC | GENERIC | ALIAS | GENERAL
  Future<TodoListResult> getList({
    String? status,
    String? tab,
    String? placeType,
    int? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (status != null) 'status': status,
      if (tab != null) 'tab': tab,
      if (placeType != null) 'placeType': placeType,
      if (cursor != null) 'cursor': cursor,
    };

    final envelope = await _client.get<TodoListResult>(
      ApiEndpoints.todos,
      queryParameters: queryParams,
      dataParser: (json) =>
          TodoListResult.fromJson(json as Map<String, dynamic>),
    );

    return envelope.data!;
  }

  // ── 상세 조회 ────────────────────────────────────────────────────
  Future<TodoDetail> getDetail(int todoId) async {
    final envelope = await _client.get<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId',
      dataParser: (json) =>
          TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  // ── 생성 ─────────────────────────────────────────────────────────
  Future<TodoCreateResult> create({
    required String content,
    required String inputType,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'inputType': inputType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };

    final envelope = await _client.post<TodoCreateResult>(
      ApiEndpoints.todos,
      data: body,
      dataParser: (json) =>
          TodoCreateResult.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  // ── 수정 ─────────────────────────────────────────────────────────
  // null = 유지 / "" = 제거 / [] = 전체 삭제
  // placeText non-empty 시 GENERIC 후보 검색을 위해 위도/경도 함께 전달
  Future<TodoDetail> update(
    int todoId, {
    String? content,
    String? category,                           // ""이면 제거
    String? placeText,                          // ""이면 제거, non-empty면 GENERIC 전환
    double? latitude,                           // placeText non-empty 시 후보 검색에 사용
    double? longitude,
    List<String>? imageUrls,                    // []이면 전체 삭제
    String? sharedUrl,                          // ""이면 제거
    List<TimeConditionRequest>? timeConditions, // []이면 전체 삭제
  }) async {
    final body = <String, dynamic>{
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (placeText != null) 'placeText': placeText,
      if (placeText != null && placeText.isNotEmpty && latitude != null)
        'latitude': latitude,
      if (placeText != null && placeText.isNotEmpty && longitude != null)
        'longitude': longitude,
      if (imageUrls != null) 'imageUrls': imageUrls,
      if (sharedUrl != null) 'sharedUrl': sharedUrl,
      if (timeConditions != null)
        'timeConditions': timeConditions.map((e) => e.toJson()).toList(),
    };

    final envelope = await _client.patch<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId',
      data: body,
      dataParser: (json) =>
          TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  // ── 알림 토글 ────────────────────────────────────────────────────
  Future<void> updateAlert(int todoId, {required bool alertEnabled}) async {
    await _client.patch<void>(
      '${ApiEndpoints.todos}/$todoId/alert',
      data: {'alertEnabled': alertEnabled},
    );
  }

  // ── 완료 상태 토글 (ACTIVE ↔ DONE) ───────────────────────────────
  Future<void> updateStatus(int todoId, {required String status}) async {
    await _client.patch<void>(
      '${ApiEndpoints.todos}/$todoId/status',
      data: {'status': status},
    );
  }

  // ── 삭제 (소프트 삭제 — status=DELETED) ──────────────────────────
  Future<void> delete(int todoId) async {
    await _client.delete<void>('${ApiEndpoints.todos}/$todoId');
  }

  // ── 장소 지정 ─────────────────────────────────────────────────────
  // FE에서 Kakao 검색으로 선택한 장소를 Todo에 연결한다.
  // kakaoPlaceId, placeName, longitude, latitude 는 필수값.
  Future<TodoDetail> setPlace(
    int todoId, {
    required String kakaoPlaceId,
    required String placeName,
    String? addressName,
    String? roadAddressName,
    String? categoryGroupCode,
    String? categoryGroupName,
    String? phone,
    String? placeUrl,
    required double longitude,
    required double latitude,
  }) async {
    final body = <String, dynamic>{
      'kakaoPlaceId': kakaoPlaceId,
      'placeName': placeName,
      if (addressName != null) 'addressName': addressName,
      if (roadAddressName != null) 'roadAddressName': roadAddressName,
      if (categoryGroupCode != null) 'categoryGroupCode': categoryGroupCode,
      if (categoryGroupName != null) 'categoryGroupName': categoryGroupName,
      if (phone != null) 'phone': phone,
      if (placeUrl != null) 'placeUrl': placeUrl,
      'longitude': longitude,
      'latitude': latitude,
    };

    final envelope = await _client.post<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId/place',
      data: body,
      dataParser: (json) => TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  // ── 장소 연결 해제 ────────────────────────────────────────────────
  // Todo에 연결된 primaryPlace를 제거하고 todoType을 GENERAL로 되돌린다.
  Future<TodoDetail> removePlace(int todoId) async {
    final envelope = await _client.delete<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId/place',
      dataParser: (json) => TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
