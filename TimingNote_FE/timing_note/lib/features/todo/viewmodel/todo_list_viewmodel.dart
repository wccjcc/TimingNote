import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../model/todo.dart';
import '../service/todo_service.dart';

// ── State ────────────────────────────────────────────────────────
class TodoListState {
  const TodoListState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.statusFilter,
    this.tabFilter,
    this.placeTypeFilter,
  });

  final List<TodoItem> items;
  final int? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? statusFilter;
  final String? tabFilter;
  final String? placeTypeFilter;

  bool get hasMore => nextCursor != null;
  bool get isEmpty => !isLoading && items.isEmpty;

  TodoListState copyWith({
    List<TodoItem>? items,
    int? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? tabFilter,
    bool clearTabFilter = false,
    String? placeTypeFilter,
    bool clearPlaceTypeFilter = false,
  }) {
    return TodoListState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      tabFilter: clearTabFilter ? null : (tabFilter ?? this.tabFilter),
      placeTypeFilter: clearPlaceTypeFilter
          ? null
          : (placeTypeFilter ?? this.placeTypeFilter),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoListNotifier extends Notifier<TodoListState> {
  static const int _limit = 20;
  static const _pendingPollInterval = Duration(seconds: 5);

  late TodoService _service;
  Timer? _pendingPollTimer;

  @override
  TodoListState build() {
    _service = ref.read(todoServiceProvider);
    ref.onDispose(() => _pendingPollTimer?.cancel());
    Future.microtask(load);
    return const TodoListState();
  }

  /// 필터 변경 + 전체 재로드
  Future<void> setFilters({
    String? status,
    bool clearStatus = false,
    String? tab,
    bool clearTab = false,
    String? placeType,
    bool clearPlaceType = false,
  }) async {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: clearStatus,
      tabFilter: tab,
      clearTabFilter: clearTab,
      placeTypeFilter: placeType,
      clearPlaceTypeFilter: clearPlaceType,
      items: [],
      clearCursor: true,
    );
    await load();
  }

  /// 첫 페이지 로드 (또는 새로고침)
  Future<void> load() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      items: [],
      clearCursor: true,
      clearError: true,
    );

    try {
      final gps = await tryGetGpsSnapshot(ref);
      final result = await _service.getList(
        status: state.statusFilter,
        tab: state.tabFilter,
        placeType: state.placeTypeFilter,
        limit: _limit,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        clearCursor: result.nextCursor == null,
        isLoading: false,
      );
      _maybeSchedulePendingPoll();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// PENDING 항목이 있으면 5초마다 목록 첫 페이지를 조용히 갱신한다.
  /// 모든 항목이 완료되면 타이머를 해제한다.
  void _maybeSchedulePendingPoll() {
    final hasPending = state.items.any((item) => item.isPending);

    if (hasPending && _pendingPollTimer == null) {
      _pendingPollTimer =
          Timer.periodic(_pendingPollInterval, (_) => _silentReload());
    } else if (!hasPending) {
      _pendingPollTimer?.cancel();
      _pendingPollTimer = null;
    }
  }

  /// 로딩 인디케이터 없이 첫 페이지만 갱신 (PENDING → READY 감지용)
  Future<void> _silentReload() async {
    if (state.isLoading || state.isLoadingMore) return;

    try {
      final result = await _service.getList(
        status: state.statusFilter,
        tab: state.tabFilter,
        placeType: state.placeTypeFilter,
        limit: _limit,
      );
      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        clearCursor: result.nextCursor == null,
      );
      _maybeSchedulePendingPoll();
    } catch (_) {
      // 조용히 실패 — 다음 주기에 재시도
    }
  }

  /// 다음 페이지 로드 (무한 스크롤)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final gps = await tryGetGpsSnapshot(ref);
      final result = await _service.getList(
        status: state.statusFilter,
        tab: state.tabFilter,
        placeType: state.placeTypeFilter,
        cursor: state.nextCursor,
        limit: _limit,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        clearCursor: result.nextCursor == null,
        isLoadingMore: false,
      );
      _maybeSchedulePendingPoll();
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 알림 토글 (낙관적 업데이트) — 후보 재계산 트리거이므로 GPS 좌표 동봉
  Future<void> toggleAlert(int todoId) async {
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;

    final original = state.items[index];
    final toggled = original.copyWith(alertEnabled: !original.alertEnabled);
    _updateItem(index, toggled);

    try {
      final gps = await tryGetGpsSnapshot(ref);
      await _service.updateAlert(
        todoId,
        alertEnabled: toggled.alertEnabled,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
    } catch (_) {
      _updateItem(index, original);
    }
  }

  /// 완료 상태 토글 (낙관적 업데이트) — monitoring 쿼리 필터 변경으로 슬롯 재계산 트리거
  Future<void> toggleStatus(int todoId) async {
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;

    final original = state.items[index];
    final newStatus = original.isDone ? TodoStatus.active : TodoStatus.done;
    final toggled = original.copyWith(
      status: newStatus,
      completedAt: newStatus == TodoStatus.done ? DateTime.now() : null,
    );
    _updateItem(index, toggled);

    try {
      final gps = await tryGetGpsSnapshot(ref);
      await _service.updateStatus(
        todoId,
        status: newStatus,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
    } catch (_) {
      _updateItem(index, original);
    }
  }

  /// 소프트 삭제 — 슬롯 비활성화를 위한 재계산 트리거이므로 GPS 4종 동봉
  Future<void> deleteTodo(int todoId) async {
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) return;

    final removed = state.items[index];
    final updated = [...state.items]..removeAt(index);
    state = state.copyWith(items: updated);

    try {
      final gps = await tryGetGpsSnapshot(ref);
      await _service.delete(
        todoId,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
    } catch (_) {
      // 실패 시 원래 위치에 복원
      final restored = [...state.items]..insert(index, removed);
      state = state.copyWith(items: restored);
    }
  }

  void _updateItem(int index, TodoItem item) {
    final updated = [...state.items];
    updated[index] = item;
    state = state.copyWith(items: updated);
  }
}

// ── Provider ─────────────────────────────────────────────────────
final todoListProvider =
    NotifierProvider<TodoListNotifier, TodoListState>(TodoListNotifier.new);
