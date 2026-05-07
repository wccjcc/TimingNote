import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_provider.dart';
import '../model/selected_kakao_place.dart';
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
  // latitude/longitude/course/occurredAt: 사용자 현재 위치 (BE 시그니처 확장 후 활용)
  Future<TodoListResult> getList({
    String? status,
    String? tab,
    String? placeType,
    int? cursor,
    int limit = 20,
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (status != null) 'status': status,
      if (tab != null) 'tab': tab,
      if (placeType != null) 'placeType': placeType,
      if (cursor != null) 'cursor': cursor,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
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
    double? course,
    DateTime? occurredAt,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'inputType': inputType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
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
  // placeText non-empty 시 GENERIC 후보 검색 + 슬롯 재계산을 위해 좌표 4종 전달
  Future<TodoDetail> update(
    int todoId, {
    String? content,
    String? category,                           // ""이면 제거
    String? placeText,                          // ""이면 제거, non-empty면 GENERIC 전환
    double? latitude,                           // placeText non-empty 시 후보 검색에 사용
    double? longitude,
    double? course,
    DateTime? occurredAt,
    List<String>? imageUrls,                    // []이면 전체 삭제
    String? sharedUrl,                          // ""이면 제거
    List<TimeConditionRequest>? timeConditions, // []이면 전체 삭제
  }) async {
    final hasPlaceText = placeText != null && placeText.isNotEmpty;
    final body = <String, dynamic>{
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (placeText != null) 'placeText': placeText,
      if (hasPlaceText && latitude != null) 'latitude': latitude,
      if (hasPlaceText && longitude != null) 'longitude': longitude,
      if (hasPlaceText && course != null) 'course': course,
      if (hasPlaceText && occurredAt != null)
        'occurredAt': occurredAt.toUtc().toIso8601String(),
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
  // latitude/longitude/course/occurredAt: 후보 재계산 시 사용
  Future<void> updateAlert(
    int todoId, {
    required bool alertEnabled,
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    final body = <String, dynamic>{
      'alertEnabled': alertEnabled,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
    await _client.patch<void>(
      '${ApiEndpoints.todos}/$todoId/alert',
      data: body,
    );
  }

  // ── 완료 상태 토글 (ACTIVE ↔ DONE) ───────────────────────────────
  Future<void> updateStatus(
    int todoId, {
    required String status,
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
    await _client.patch<void>(
      '${ApiEndpoints.todos}/$todoId/status',
      data: body,
    );
  }

  // ── 삭제 (소프트 삭제 — status=DELETED) ──────────────────────────
  // BE: DELETE /api/v1/todos?ids=1,2,3 (단건/다중 동일 엔드포인트)
  Future<void> delete(
    int todoId, {
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    await _client.delete<void>(
      ApiEndpoints.todos,
      queryParameters: {
        'ids': todoId.toString(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (course != null) 'course': course,
        if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteMany(
    List<int> todoIds, {
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    if (todoIds.isEmpty) return;
    await _client.delete<void>(
      ApiEndpoints.todos,
      queryParameters: {
        'ids': todoIds.join(','),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (course != null) 'course': course,
        if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  // ── 장소 지정 — ALIAS (내 장소) ───────────────────────────────────
  // BE: POST /todos/{id}/place — userPlaceId만 포함, externalPlace는 null
  Future<TodoDetail> setAliasPlace(
    int todoId, {
    required int userPlaceId,
    double? userLatitude,
    double? userLongitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    final body = <String, dynamic>{
      'userPlaceId': userPlaceId,
      if (userLatitude != null) 'latitude': userLatitude,
      if (userLongitude != null) 'longitude': userLongitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
    };

    final envelope = await _client.post<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId/place',
      data: body,
      dataParser: (json) => TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  // ── 장소 지정 — SPECIFIC (외부 장소) ─────────────────────────────
  // BE: POST /todos/{id}/place — externalPlace 객체로 묶어서 전달
  // kakaoPlaceId는 키워드 검색 결과만 존재 (지도 핀 직접 선택 시 null)
  Future<TodoDetail> setExternalPlace(
    int todoId, {
    required SelectedExternalPlace place,
    double? userLatitude,
    double? userLongitude,
    double? course,
    DateTime? occurredAt,
  }) async {
    final externalPlace = <String, dynamic>{
      if (place.kakaoPlaceId != null) 'kakaoPlaceId': place.kakaoPlaceId,
      'placeName': place.placeName,
      'latitude': place.placeLatitude,
      'longitude': place.placeLongitude,
      if (place.addressName != null) 'addressName': place.addressName,
      if (place.roadAddressName != null) 'roadAddressName': place.roadAddressName,
      if (place.categoryGroupCode != null) 'categoryGroupCode': place.categoryGroupCode,
      if (place.categoryGroupName != null) 'categoryGroupName': place.categoryGroupName,
      if (place.phone != null) 'phone': place.phone,
      if (place.placeUrl != null) 'placeUrl': place.placeUrl,
    };

    final body = <String, dynamic>{
      'externalPlace': externalPlace,
      if (userLatitude != null) 'latitude': userLatitude,
      if (userLongitude != null) 'longitude': userLongitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
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
