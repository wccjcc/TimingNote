import 'package:flutter/foundation.dart' show debugPrint;
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
      // [TIMING] 임시 측정 — 등록 응답 지연 원인 진단용. 결과 확인 후 제거 또는 영구화 결정.
      final tSubmit = DateTime.now();
      // 등록 직전 GPS — forceFresh=false (2026-05-13).
      // 캐시·디바이스 lastKnownPosition 우선 사용 → 응답 즉시화. 차량 이동 케이스도 OS가
      // 백그라운드로 좌표 유지하므로 stale 거의 없음. 등록 직후 유의미한 이동 신호 발생 시
      // GenericCandidateRefreshService가 후보 풀 재계산해 stale 잔류분도 자동 보정.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: false);
      final tGps = DateTime.now();
      debugPrint('[TIMING] GPS step: ${tGps.difference(tSubmit).inMilliseconds}ms '
          '(forceFresh=false, gps=${gps != null ? "ok" : "null"})');

      final mergedContent = _mergeAliasIntoContent(
        state.content.trim(),
        state.selectedUserPlace?.aliasName,
      );
      final result = await _service.create(
        content: mergedContent,
        inputType: state.inputType,
        latitude: gps?.latitude ?? state.latitude,
        longitude: gps?.longitude ?? state.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
        userPlaceId: state.selectedUserPlace?.id,
      );
      final tBe = DateTime.now();
      debugPrint('[TIMING] BE create: ${tBe.difference(tGps).inMilliseconds}ms');
      debugPrint('[TIMING] TOTAL:     ${tBe.difference(tSubmit).inMilliseconds}ms');

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

/// 입력창의 prefix chip(별칭)은 controller.text에 포함되지 않으므로,
/// submit 직전에 aliasName을 본문 앞에 합쳐서 BE/검색/표시에 일관되게 들어가도록 한다.
///
/// 규칙:
/// - aliasName 없음 → 본문 그대로
/// - 본문에 이미 aliasName 포함 → 그대로 (사용자가 직접 입력한 케이스)
/// - 본문이 한국어 조사로 시작 → "별칭+본문" 공백 없이 ("에서 밥먹기" → "집에서 밥먹기")
/// - 그 외 → "별칭 본문" 공백 한 칸
String _mergeAliasIntoContent(String content, String? aliasName) {
  final alias = aliasName?.trim();
  if (alias == null || alias.isEmpty) return content;
  if (content.isEmpty) return alias;
  if (content.contains(alias)) return content;

  const particles = ['에서', '에게', '한테', '으로부터', '으로', '부터', '까지'];
  final hasParticlePrefix = particles.any(content.startsWith);
  return hasParticlePrefix ? '$alias$content' : '$alias $content';
}

// ── Provider ─────────────────────────────────────────────────────
final todoInputProvider =
    NotifierProvider.autoDispose<TodoInputNotifier, TodoInputState>(
  TodoInputNotifier.new,
);
