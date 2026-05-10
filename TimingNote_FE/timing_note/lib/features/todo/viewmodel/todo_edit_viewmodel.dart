import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/location/location_provider.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../model/todo_detail.dart';
import '../service/todo_service.dart';
import 'todo_detail_viewmodel.dart';
import 'todo_list_viewmodel.dart';

// ── State ────────────────────────────────────────────────────────
class TodoEditState {
  const TodoEditState({
    this.original,
    this.content,
    this.category,
    this.placeText,
    this.latitude,
    this.longitude,
    this.imageUrls,
    this.imagePreviewBytes = const {},
    this.sharedUrl,
    this.timeConditions,
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingImage = false,
    this.error,
    this.savedDetail,
  });

  final TodoDetail? original;
  final String? content;
  final String? category;
  final String? placeText;
  final double? latitude; // placeText GENERIC 전환 시 Kakao 후보 검색에 사용
  final double? longitude;
  final List<String>? imageUrls;
  final Map<String, Uint8List> imagePreviewBytes;
  final String? sharedUrl;
  final List<TimeConditionRequest>? timeConditions;
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingImage;
  final String? error;
  final TodoDetail? savedDetail;

  bool get isReady => original != null && !isLoading;
  bool get canSave => isReady && !isSaving && !isUploadingImage;

  TodoEditState copyWith({
    TodoDetail? original,
    String? content,
    String? category,
    String? placeText,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    Map<String, Uint8List>? imagePreviewBytes,
    String? sharedUrl,
    List<TimeConditionRequest>? timeConditions,
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingImage,
    String? error,
    bool clearError = false,
    TodoDetail? savedDetail,
  }) {
    return TodoEditState(
      original: original ?? this.original,
      content: content ?? this.content,
      category: category ?? this.category,
      placeText: placeText ?? this.placeText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      imagePreviewBytes: imagePreviewBytes ?? this.imagePreviewBytes,
      sharedUrl: sharedUrl ?? this.sharedUrl,
      timeConditions: timeConditions ?? this.timeConditions,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      error: clearError ? null : (error ?? this.error),
      savedDetail: savedDetail ?? this.savedDetail,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoEditNotifier extends AutoDisposeFamilyNotifier<TodoEditState, int> {
  late TodoService _service;
  late int _todoId;

  @override
  TodoEditState build(int arg) {
    _todoId = arg;
    _service = ref.read(todoServiceProvider);
    Future.microtask(_load);
    return const TodoEditState();
  }

  // ── 초기 로드 ─────────────────────────────────────────────────────

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _service.getDetail(_todoId);
      state = state.copyWith(
        original: detail,
        isLoading: false,
        content: detail.content,
        category: detail.category ?? TodoCategory.etc,
        placeText: detail.structure?.placeText ?? '',
        imageUrls: List<String>.from(detail.imageUrls),
        imagePreviewBytes: const {},
        sharedUrl: detail.sharedUrl ?? '',
        timeConditions: detail.timeConditions
            .map(TimeConditionRequest.fromCondition)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── 폼 필드 업데이트 ─────────────────────────────────────────────

  void setContent(String value) => state = state.copyWith(content: value);
  void setCategory(String value) => state = state.copyWith(category: value);
  void setPlaceText(String value) => state = state.copyWith(placeText: value);
  void setSharedUrl(String value) => state = state.copyWith(sharedUrl: value);

  /// placeText GENERIC 전환 시 Kakao 후보 검색을 위한 좌표 설정
  void setLocation(double latitude, double longitude) =>
      state = state.copyWith(latitude: latitude, longitude: longitude);

  // ── 이미지 URL 관리 ───────────────────────────────────────────────

  void addImageUrl(String url) {
    final current = List<String>.from(state.imageUrls ?? []);
    if (!current.contains(url)) current.add(url);
    state = state.copyWith(imageUrls: current);
  }

  void removeImageUrl(String url) {
    final current = List<String>.from(state.imageUrls ?? [])..remove(url);
    final preview = Map<String, Uint8List>.from(state.imagePreviewBytes)
      ..remove(url);
    state = state.copyWith(imageUrls: current, imagePreviewBytes: preview);
  }

  void clearImageUrls() => state = state.copyWith(imageUrls: []);

  /// 갤러리에서 선택한 이미지를 바로 S3에 업로드하고 objectKey를 상태에 추가한다.
  /// 화면에서는 이 메서드만 호출하면 되어, 업로드/오류/중복제어를 한 곳에서 관리할 수 있다.
  Future<void> uploadPickedImage(XFile imageFile) async {
    if (state.isUploadingImage) return;

    final current = List<String>.from(state.imageUrls ?? []);
    if (current.length >= 3) {
      state = state.copyWith(error: '이미지는 최대 3장까지 등록할 수 있습니다.');
      return;
    }

    state = state.copyWith(isUploadingImage: true, clearError: true);
    try {
      // 업로드 전 바이트를 읽어 로컬 미리보기에 사용한다.
      final previewBytes = await imageFile.readAsBytes();
      final objectKey = await _service.uploadImageToS3(imageFile: imageFile);
      final current = List<String>.from(state.imageUrls ?? []);
      if (!current.contains(objectKey)) current.add(objectKey);
      final preview = Map<String, Uint8List>.from(state.imagePreviewBytes)
        ..[objectKey] = previewBytes;
      state = state.copyWith(
        imageUrls: current,
        imagePreviewBytes: preview,
        isUploadingImage: false,
      );
    } catch (_) {
      state = state.copyWith(
        isUploadingImage: false,
        error: '이미지 업로드에 실패했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  // ── 시간 조건 관리 ────────────────────────────────────────────────

  void addTimeCondition(TimeConditionRequest tc) {
    final current = List<TimeConditionRequest>.from(state.timeConditions ?? []);
    current.add(tc);
    state = state.copyWith(timeConditions: current);
  }

  void updateTimeCondition(int index, TimeConditionRequest tc) {
    final current = List<TimeConditionRequest>.from(state.timeConditions ?? []);
    if (index < 0 || index >= current.length) return;
    current[index] = tc;
    state = state.copyWith(timeConditions: current);
  }

  void removeTimeCondition(int index) {
    final current = List<TimeConditionRequest>.from(state.timeConditions ?? []);
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    state = state.copyWith(timeConditions: current);
  }

  void clearTimeConditions() => state = state.copyWith(timeConditions: []);

  // ── 저장 ─────────────────────────────────────────────────────────

  Future<void> save() async {
    if (!state.canSave) return;

    final orig = state.original!;

    final contentToSend = state.content != orig.content ? state.content : null;
    final categoryToSend = (state.category ?? '') != (orig.category ?? '')
        ? state.category
        : null;
    final placeTextToSend =
        (state.placeText ?? '') != (orig.structure?.placeText ?? '')
        ? state.placeText
        : null;
    final sharedUrlToSend = (state.sharedUrl ?? '') != (orig.sharedUrl ?? '')
        ? state.sharedUrl
        : null;

    final origImages = orig.imageUrls;
    final editImages = state.imageUrls ?? origImages;
    final imageUrlsToSend = _listEquals(origImages, editImages)
        ? null
        : editImages;

    final origTcKeys = orig.timeConditions.map(_tcKey).toList();
    final editTcKeys = (state.timeConditions ?? []).map(_tcRequestKey).toList();
    final timeConditionsToSend = _listStringEquals(origTcKeys, editTcKeys)
        ? null
        : state.timeConditions;

    if (contentToSend == null &&
        categoryToSend == null &&
        placeTextToSend == null &&
        sharedUrlToSend == null &&
        imageUrlsToSend == null &&
        timeConditionsToSend == null) {
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      // placeText가 non-empty면 GENERIC 후보 검색 + 슬롯 재계산이 일어나므로 GPS 호출
      final needsLocation =
          placeTextToSend != null && placeTextToSend.isNotEmpty;
      final gps = needsLocation ? await tryGetGpsSnapshot(ref) : null;

      final updated = await _service.update(
        _todoId,
        content: contentToSend,
        category: categoryToSend,
        placeText: placeTextToSend,
        latitude: gps?.latitude ?? (needsLocation ? state.latitude : null),
        longitude: gps?.longitude ?? (needsLocation ? state.longitude : null),
        course: gps?.course,
        occurredAt: gps?.occurredAt,
        sharedUrl: sharedUrlToSend,
        imageUrls: imageUrlsToSend,
        timeConditions: timeConditionsToSend,
      );

      // pop 전에 관련 프로바이더 무효화 → 돌아갔을 때 최신 데이터 표시
      ref.invalidate(todoDetailProvider(_todoId));
      ref.invalidate(todoListProvider);

      state = state.copyWith(
        isSaving: false,
        original: updated,
        savedDetail: updated,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  // ── 비교 유틸 ─────────────────────────────────────────────────────

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _listStringEquals(List<String> a, List<String> b) => _listEquals(a, b);

  String _tcKey(dynamic tc) =>
      '${tc.conditionType}|${tc.startDate}|${tc.endDate}|'
      '${tc.startTime}|${tc.endTime}|${tc.daysOfWeek}|${tc.rawExpression}';

  String _tcRequestKey(TimeConditionRequest tc) =>
      '${tc.conditionType}|${tc.startDate}|${tc.endDate}|'
      '${tc.startTime}|${tc.endTime}|${tc.daysOfWeek?.join(",")}|${tc.rawExpression}';
}

// ── Provider ─────────────────────────────────────────────────────
final todoEditProvider = NotifierProvider.autoDispose
    .family<TodoEditNotifier, TodoEditState, int>(TodoEditNotifier.new);
