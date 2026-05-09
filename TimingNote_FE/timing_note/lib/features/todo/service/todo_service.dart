import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;

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

  /// 이미지 업로드용 Presigned URL 발급
  Future<_PresignedUploadInfo> _issueImagePresignedUrl({
    required String contentType,
    required int fileSize,
  }) async {
    final envelope = await _client.post<_PresignedUploadInfo>(
      ApiEndpoints.imageUploadUrl,
      data: {
        'contentType': contentType,
        'fileSize': fileSize,
      },
      dataParser: (json) =>
          _PresignedUploadInfo.fromJson(json as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  Future<Map<String, String>> _issueImageDownloadUrls({
    required List<String> objectKeys,
  }) async {
    if (objectKeys.isEmpty) return const {};

    final envelope = await _client.post<_PresignedDownloadUrlsResponse>(
      ApiEndpoints.imageDownloadUrls,
      data: {
        'objectKeys': objectKeys,
      },
      dataParser: (json) => _PresignedDownloadUrlsResponse.fromJson(
        json as Map<String, dynamic>,
      ),
    );

    return envelope.data!.toMap();
  }

  /// Presigned PUT URL로 S3에 바이너리를 직접 업로드하고 objectKey를 반환
  Future<String> uploadImageToS3({
    required XFile imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final contentType = _resolveContentType(imageFile.name);

    // 1) 백엔드에서 presigned URL 발급
    final presigned = await _issueImagePresignedUrl(
      contentType: contentType,
      fileSize: bytes.length,
    );

    // 2) 발급받은 URL로 S3 PUT 업로드
    // 앱 API용 Dio(baseUrl 포함)와 분리해 절대 URL 업로드를 안전하게 수행한다.
    final uploadDio = Dio();
    try {
      await uploadDio.put<void>(
        presigned.uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': contentType},
          contentType: contentType,
          responseType: ResponseType.plain,
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      developer.log(
        '[S3 Upload Fail] status=$status, type=${e.type}, message=${e.message}, body=$body',
        name: 'TodoService.uploadImageToS3',
      );
      throw Exception('S3_UPLOAD_FAILED(status=$status, type=${e.type})');
    }

    // 3) Todo update payload에는 URL이 아니라 objectKey를 저장한다.
    return presigned.objectKey;
  }

  String _resolveContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        // iOS 사진 선택기에서 확장자 정보가 불완전한 경우가 있어 기본값을 jpeg로 둔다.
        return 'image/jpeg';
    }
  }

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
    final result = envelope.data!;
    final thumbnailKeys = result.items
        .map((e) => e.thumbnailUrl)
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final downloadUrlMap = await _issueImageDownloadUrls(objectKeys: thumbnailKeys);

    final resolvedItems = result.items.map((item) {
      final key = item.thumbnailUrl;
      if (key == null || key.trim().isEmpty) return item;
      final downloadUrl = downloadUrlMap[key];
      if (downloadUrl == null || downloadUrl.isEmpty) return item;
      return item.copyWith(thumbnailUrl: downloadUrl);
    }).toList();

    return TodoListResult(items: resolvedItems, nextCursor: result.nextCursor);
  }

  // ── 상세 조회 ────────────────────────────────────────────────────
  Future<TodoDetail> getDetail(int todoId) async {
    final envelope = await _client.get<TodoDetail>(
      '${ApiEndpoints.todos}/$todoId',
      dataParser: (json) =>
          TodoDetail.fromJson(json as Map<String, dynamic>),
    );
    final detail = envelope.data!;
    if (detail.imageUrls.isEmpty) return detail;

    final downloadUrlMap = await _issueImageDownloadUrls(objectKeys: detail.imageUrls);
    final resolved = detail.imageUrls
        .map((key) => downloadUrlMap[key] ?? key)
        .toList();
    return detail.copyWith(imageUrls: resolved);
  }

  // ── 생성 ─────────────────────────────────────────────────────────
  // userPlaceId: 사용자가 명시 선택한 내 장소 ID (옵셔널).
  //   있으면 BE는 AI 응답의 placeText 검색 없이 ID로 직접 ALIAS 연결.
  Future<TodoCreateResult> create({
    required String content,
    required String inputType,
    double? latitude,
    double? longitude,
    double? course,
    DateTime? occurredAt,
    int? userPlaceId,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'inputType': inputType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (course != null) 'course': course,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
      if (userPlaceId != null) 'userPlaceId': userPlaceId,
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

class _PresignedUploadInfo {
  const _PresignedUploadInfo({
    required this.objectKey,
    required this.uploadUrl,
  });

  final String objectKey;
  final String uploadUrl;

  factory _PresignedUploadInfo.fromJson(Map<String, dynamic> json) {
    return _PresignedUploadInfo(
      objectKey: json['objectKey'] as String? ?? '',
      uploadUrl: json['uploadUrl'] as String? ?? '',
    );
  }
}

class _PresignedDownloadUrlsResponse {
  const _PresignedDownloadUrlsResponse({required this.items});

  final List<_PresignedDownloadUrlItem> items;

  factory _PresignedDownloadUrlsResponse.fromJson(Map<String, dynamic> json) {
    return _PresignedDownloadUrlsResponse(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => _PresignedDownloadUrlItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, String> toMap() {
    final map = <String, String>{};
    for (final item in items) {
      if (item.objectKey.isEmpty || item.downloadUrl.isEmpty) continue;
      map[item.objectKey] = item.downloadUrl;
    }
    return map;
  }
}

class _PresignedDownloadUrlItem {
  const _PresignedDownloadUrlItem({
    required this.objectKey,
    required this.downloadUrl,
  });

  final String objectKey;
  final String downloadUrl;

  factory _PresignedDownloadUrlItem.fromJson(Map<String, dynamic> json) {
    return _PresignedDownloadUrlItem(
      objectKey: json['objectKey'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }
}
