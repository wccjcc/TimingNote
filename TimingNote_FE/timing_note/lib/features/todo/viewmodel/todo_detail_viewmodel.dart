import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/todo.dart';
import '../model/todo_detail.dart';
import '../service/todo_service.dart';
import 'todo_list_viewmodel.dart';

// ── State ────────────────────────────────────────────────────────
class TodoDetailState {
  const TodoDetailState({
    this.detail,
    this.isLoading = false,
    this.error,
  });

  final TodoDetail? detail;
  final bool isLoading;
  final String? error;

  TodoDetailState copyWith({
    TodoDetail? detail,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TodoDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoDetailNotifier extends FamilyNotifier<TodoDetailState, int> {
  late TodoService _service;
  late int _todoId;
  Timer? _pollTimer;

  @override
  TodoDetailState build(int arg) {
    _todoId = arg;
    _service = ref.read(todoServiceProvider);
    // 화면이 dispose될 때 폴링 타이머 자동 취소
    ref.onDispose(() => _pollTimer?.cancel());
    // 초기 로드
    Future.microtask(load);
    return const TodoDetailState();
  }

  /// 상세 로드
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _service.getDetail(_todoId);
      state = state.copyWith(detail: detail, isLoading: false);

      if (detail.isPending) _startPolling();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// PENDING → READY/FAILED 감지 폴링 (2초 간격, 최대 10회)
  void _startPolling() {
    _pollTimer?.cancel();
    var attempts = 0;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 10) {
        timer.cancel();
        return;
      }
      try {
        final detail = await _service.getDetail(_todoId);
        if (!detail.isPending) {
          timer.cancel();
          state = state.copyWith(detail: detail);
        }
      } catch (_) {}
    });
  }

  /// 알림 토글 (낙관적 업데이트)
  Future<void> toggleAlert() async {
    final current = state.detail;
    if (current == null) return;

    final toggled = current.copyWith(alertEnabled: !current.alertEnabled);
    state = state.copyWith(detail: toggled);

    try {
      await _service.updateAlert(_todoId, alertEnabled: toggled.alertEnabled);
    } catch (_) {
      state = state.copyWith(detail: current);
    }
  }

  /// 완료 상태 토글 (낙관적 업데이트)
  Future<void> toggleStatus() async {
    final current = state.detail;
    if (current == null) return;

    final newStatus = current.isDone ? TodoStatus.active : TodoStatus.done;
    final toggled = current.copyWith(
      status: newStatus,
      completedAt: newStatus == TodoStatus.done ? DateTime.now() : null,
    );
    state = state.copyWith(detail: toggled);

    try {
      await _service.updateStatus(_todoId, status: newStatus);
    } catch (_) {
      state = state.copyWith(detail: current);
    }
  }

  /// 소프트 삭제 — 완료 후 화면을 pop하는 것은 View 책임
  Future<bool> deleteTodo() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.delete(_todoId);
      ref.invalidate(todoListProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 장소 지정 — Kakao 검색 결과를 Todo에 연결
  Future<void> setPlace({
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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.setPlace(
        _todoId,
        kakaoPlaceId: kakaoPlaceId,
        placeName: placeName,
        addressName: addressName,
        roadAddressName: roadAddressName,
        categoryGroupCode: categoryGroupCode,
        categoryGroupName: categoryGroupName,
        phone: phone,
        placeUrl: placeUrl,
        longitude: longitude,
        latitude: latitude,
      );
      state = state.copyWith(detail: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 장소 연결 해제
  Future<void> removePlace() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.removePlace(_todoId);
      state = state.copyWith(detail: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ── Provider (todoId별 독립 인스턴스) ─────────────────────────────
final todoDetailProvider =
    NotifierProvider.family<TodoDetailNotifier, TodoDetailState, int>(
  TodoDetailNotifier.new,
);
