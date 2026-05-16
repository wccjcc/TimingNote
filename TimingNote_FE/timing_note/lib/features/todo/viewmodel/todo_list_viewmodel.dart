import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../home/viewmodel/home_recommendation_viewmodel.dart';
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
    this.currentGps,
  });

  final List<TodoItem> items;
  final int? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? statusFilter;
  final String? tabFilter;
  final String? placeTypeFilter;
  /// 마지막 목록 조회 시점의 사용자 GPS — 항목별 거리 표시에 사용.
  /// 권한 거부/GPS 실패 시 null.
  final GpsSnapshot? currentGps;

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
    GpsSnapshot? currentGps,
    bool clearCurrentGps = false,
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
      currentGps: clearCurrentGps ? null : (currentGps ?? this.currentGps),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoListNotifier extends Notifier<TodoListState> {
  static const int _limit = 20;
  static const _pendingPollInterval = Duration(seconds: 5);

  late TodoService _service;
  Timer? _pendingPollTimer;

  /// 진행 중인 항목 단위 액션(토글/삭제) — 같은 todoId 더블 탭 시 두 번째 호출을 차단.
  /// state로 두면 매 변경마다 rebuild라 부담 → 로컬 Set으로 가벼운 가드.
  final Set<int> _inflightItemActions = <int>{};

  @override
  TodoListState build() {
    _service = ref.read(todoServiceProvider);
    ref.onDispose(() => _pendingPollTimer?.cancel());
    Future.microtask(load);
    return const TodoListState();
  }

  /// 필터 변경 + 전체 재로드.
  /// 동일 필터로 호출 시 noop — 칩 재탭/검색 컨텍스트 갱신 등에서 불필요한 BE 호출 차단.
  /// 호출자(UI)에서 막아도 animation 끝 시점 listener 등 우회 경로가 있어 viewmodel 측이 최종 가드.
  Future<void> setFilters({
    String? status,
    bool clearStatus = false,
    String? tab,
    bool clearTab = false,
    String? placeType,
    bool clearPlaceType = false,
  }) async {
    // 호출자가 보낸 의도 = clearXxx면 null, 아니면 xxx 그대로
    final intendedStatus = clearStatus ? null : status;
    final intendedTab = clearTab ? null : tab;
    final intendedPlaceType = clearPlaceType ? null : placeType;

    // 현재 state와 정확히 동일하면 reload 불필요
    if (intendedStatus == state.statusFilter &&
        intendedTab == state.tabFilter &&
        intendedPlaceType == state.placeTypeFilter) {
      return;
    }

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
        currentGps: gps,
        clearCurrentGps: gps == null,
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
  /// 페이지 사이의 짧은 이동은 거리 표시에 의미 없어 GPS 새로 받지 않고 state.currentGps 재사용.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final gps = state.currentGps;
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
    // 더블 탭 가드 — 같은 todo가 진행 중이면 두 번째 호출 무시.
    // BE updateAlert 중복 호출 시 슬롯 재계산이 race 가능.
    if (!_inflightItemActions.add(todoId)) return;
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) {
      _inflightItemActions.remove(todoId);
      return;
    }

    final original = state.items[index];
    final toggled = original.copyWith(alertEnabled: !original.alertEnabled);
    _updateItem(index, toggled);

    try {
      // 알림 슬롯 재계산은 좌표 정확도에 의존 — forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
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
    } finally {
      _inflightItemActions.remove(todoId);
    }
  }

  /// 완료 상태 토글 (낙관적 업데이트) — monitoring 쿼리 필터 변경으로 슬롯 재계산 트리거
  Future<void> toggleStatus(int todoId) async {
    if (!_inflightItemActions.add(todoId)) return;
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) {
      _inflightItemActions.remove(todoId);
      return;
    }

    final original = state.items[index];
    final newStatus = original.isDone ? TodoStatus.active : TodoStatus.done;
    final toggled = original.copyWith(
      status: newStatus,
      completedAt: newStatus == TodoStatus.done ? DateTime.now() : null,
    );
    _updateItem(index, toggled);

    try {
      // status 변경 → 슬롯 재계산. forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      await _service.updateStatus(
        todoId,
        status: newStatus,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      ref.invalidate(homeRecommendationProvider);
    } catch (_) {
      _updateItem(index, original);
    } finally {
      _inflightItemActions.remove(todoId);
    }
  }

  /// 소프트 삭제 — 슬롯 비활성화를 위한 재계산 트리거이므로 GPS 4종 동봉
  Future<void> deleteTodo(int todoId) async {
    if (!_inflightItemActions.add(todoId)) return;
    final index = state.items.indexWhere((e) => e.id == todoId);
    if (index == -1) {
      _inflightItemActions.remove(todoId);
      return;
    }

    final removed = state.items[index];
    final updated = [...state.items]..removeAt(index);
    state = state.copyWith(items: updated);

    try {
      // 삭제는 슬롯 정리(재계산) 트리거 — forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      await _service.delete(
        todoId,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      ref.invalidate(homeRecommendationProvider);
    } catch (_) {
      // 실패 시 원래 위치에 복원
      final restored = [...state.items]..insert(index, removed);
      state = state.copyWith(items: restored);
    } finally {
      _inflightItemActions.remove(todoId);
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
