import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../mypage/model/user_place.dart';
import '../model/todo.dart';
import '../service/todo_service.dart';

// ── State ────────────────────────────────────────────────────────
// pending 단계 제거: AI 구조화 대기는 목록 화면 카드 스피너에서 처리한다.
enum InputSubmitPhase { idle, submitting, done, error }

class TodoInputState {
  const TodoInputState({
    this.content = '',
    this.inputType = InputType.text,
    this.latitude,
    this.longitude,
    this.selectedUserPlace,
    this.phase = InputSubmitPhase.idle,
    this.createdTodoId,
    this.structureStatus,
    this.error,
  });

  final String content;
  final String inputType;
  final double? latitude;
  final double? longitude;
  /// 사용자가 명시 선택한 내 장소. submit 시 userPlaceId로 BE에 전달.
  final UserPlace? selectedUserPlace;
  final InputSubmitPhase phase;
  final int? createdTodoId;
  final String? structureStatus;
  final String? error;

  bool get isSubmitting => phase == InputSubmitPhase.submitting;
  bool get isCompleted => phase == InputSubmitPhase.done;
  bool get canSubmit =>
      content.trim().isNotEmpty && phase == InputSubmitPhase.idle;

  TodoInputState copyWith({
    String? content,
    String? inputType,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    UserPlace? selectedUserPlace,
    bool clearUserPlace = false,
    InputSubmitPhase? phase,
    int? createdTodoId,
    String? structureStatus,
    String? error,
    bool clearError = false,
  }) {
    return TodoInputState(
      content: content ?? this.content,
      inputType: inputType ?? this.inputType,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      selectedUserPlace: clearUserPlace ? null : (selectedUserPlace ?? this.selectedUserPlace),
      phase: phase ?? this.phase,
      createdTodoId: createdTodoId ?? this.createdTodoId,
      structureStatus: structureStatus ?? this.structureStatus,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoInputNotifier extends AutoDisposeNotifier<TodoInputState> {
  late final TodoService _service;

  @override
  TodoInputState build() {
    _service = ref.read(todoServiceProvider);
    return const TodoInputState();
  }

  // ── 폼 필드 업데이트 ─────────────────────────────────────────────

  void setContent(String value) => state = state.copyWith(content: value);

  void setInputType(String type) => state = state.copyWith(inputType: type);

  void setLocation({required double latitude, required double longitude}) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
  }

  void clearLocation() => state = state.copyWith(clearLocation: true);

  void setUserPlace(UserPlace place) => state = state.copyWith(selectedUserPlace: place);

  void clearUserPlace() => state = state.copyWith(clearUserPlace: true);

  // ── 제출 ─────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(phase: InputSubmitPhase.submitting, clearError: true);

    try {
      // AI가 GENERIC 후보 검색 시 사용자 위치 기준이 필요하므로 등록 직전 GPS 호출
      final gps = await tryGetGpsSnapshot(ref);
      final result = await _service.create(
        content: state.content.trim(),
        inputType: state.inputType,
        latitude: gps?.latitude ?? state.latitude,
        longitude: gps?.longitude ?? state.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
        userPlaceId: state.selectedUserPlace?.id,
      );

      // PENDING 여부와 무관하게 즉시 done 처리.
      // AI 구조화 대기 스피너는 할 일 목록 카드에서 표시한다.
      state = state.copyWith(
        phase: InputSubmitPhase.done,
        createdTodoId: result.todoId,
        structureStatus: result.structureStatus,
      );
    } catch (e) {
      state = state.copyWith(phase: InputSubmitPhase.error, error: e.toString());
    }
  }

  void resetError() {
    state = state.copyWith(phase: InputSubmitPhase.idle, clearError: true);
  }

  void reset() {
    state = const TodoInputState();
  }
}

// ── Provider ─────────────────────────────────────────────────────
final todoInputProvider =
    NotifierProvider.autoDispose<TodoInputNotifier, TodoInputState>(
  TodoInputNotifier.new,
);
