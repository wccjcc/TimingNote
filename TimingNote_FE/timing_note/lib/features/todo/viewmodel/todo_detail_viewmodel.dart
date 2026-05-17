import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../home/viewmodel/home_recommendation_viewmodel.dart';
import '../model/selected_kakao_place.dart';
import '../model/time_condition.dart';
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
    this.currentGps,
  });

  final TodoDetail? detail;
  final bool isLoading;
  final String? error;
  /// 상세 로드/액션 시 확보한 사용자 위치. 거리 표시(현재위치 ↔ 장소)에 사용.
  /// 권한 거부 / GPS 실패 시 null.
  final GpsSnapshot? currentGps;

  TodoDetailState copyWith({
    TodoDetail? detail,
    bool? isLoading,
    String? error,
    bool clearError = false,
    GpsSnapshot? currentGps,
    bool clearGps = false,
  }) {
    return TodoDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentGps: clearGps ? null : (currentGps ?? this.currentGps),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class TodoDetailNotifier extends FamilyNotifier<TodoDetailState, int> {
  late TodoService _service;
  late int _todoId;
  Timer? _pollTimer;

  /// 메서드 더블 탭 가드 — 진행 중인 액션이 있으면 두 번째 호출 무시.
  /// state.isLoading은 일부 메서드만 set하고 UI 표시도 일부에만 노출되어 일관성 없음.
  /// 별도 로컬 플래그로 모든 mutating 액션을 일괄 보호.
  bool _inflight = false;

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
  ///
  /// GPS와 getDetail은 서로 독립(getDetail이 좌표 인자를 받지 않음)이라 병렬로 수행.
  /// 직렬 대비 max(GPS, BE RTT)로 단축 — 특히 GPS 캐시 miss인 첫 진입에서 체감 효과.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<Object?>([
        tryGetGpsSnapshot(ref),
        _service.getDetail(_todoId),
      ]);
      final gps = results[0] as GpsSnapshot?;
      final detail = results[1] as TodoDetail;
      state = state.copyWith(
        detail: detail,
        isLoading: false,
        currentGps: gps,
        clearGps: gps == null,
      );

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

  /// 알림 토글 (낙관적 업데이트) — 후보 재계산 트리거이므로 GPS 4종 동봉
  Future<void> toggleAlert() async {
    if (_inflight) return;
    _inflight = true;
    final current = state.detail;
    if (current == null) {
      _inflight = false;
      return;
    }

    final toggled = current.copyWith(alertEnabled: !current.alertEnabled);
    state = state.copyWith(detail: toggled);

    try {
      // 알림 슬롯 재계산은 좌표 의존 — forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      await _service.updateAlert(
        _todoId,
        alertEnabled: toggled.alertEnabled,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (_) {
      state = state.copyWith(detail: current);
    } finally {
      _inflight = false;
    }
  }

  /// 완료 상태 토글 (낙관적 업데이트) — monitoring 쿼리 필터 변경으로 슬롯 재계산
  Future<void> toggleStatus() async {
    if (_inflight) return;
    _inflight = true;
    final current = state.detail;
    if (current == null) {
      _inflight = false;
      return;
    }

    final newStatus = current.isDone ? TodoStatus.active : TodoStatus.done;
    final toggled = current.copyWith(
      status: newStatus,
      completedAt: newStatus == TodoStatus.done ? DateTime.now() : null,
    );
    state = state.copyWith(detail: toggled);

    try {
      // status 변경 → 슬롯 재계산. forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      await _service.updateStatus(
        _todoId,
        status: newStatus,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (_) {
      state = state.copyWith(detail: current);
    } finally {
      _inflight = false;
    }
  }

  /// 소프트 삭제 — 슬롯 비활성화 트리거이므로 GPS 4종 동봉
  Future<bool> deleteTodo() async {
    if (_inflight) return false;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 삭제 → 슬롯 정리 재계산. forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      await _service.delete(
        _todoId,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    } finally {
      _inflight = false;
    }
  }

  /// 장소 지정 — ALIAS (내 장소) 선택. GPS 4종은 호출 시점에 가져옴.
  Future<void> setAliasPlace({required int userPlaceId}) async {
    if (_inflight) return;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 장소 지정 → BE 후보 재검색 + 슬롯 재계산. forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      final updated = await _service.setAliasPlace(
        _todoId,
        userPlaceId: userPlaceId,
        userLatitude: gps?.latitude,
        userLongitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      state = state.copyWith(detail: updated, isLoading: false);
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }

  /// 장소 지정 — SPECIFIC (외부 장소). GPS 4종은 호출 시점에 가져옴.
  Future<void> setExternalPlace({required SelectedExternalPlace place}) async {
    if (_inflight) return;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // SPECIFIC 장소 설정 → BE 후보 재검색 + 슬롯 재계산. forceFresh.
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      final updated = await _service.setExternalPlace(
        _todoId,
        place: place,
        userLatitude: gps?.latitude,
        userLongitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      state = state.copyWith(detail: updated, isLoading: false);
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }

  // ── 시간 조건 CRUD ─────────────────────────────────────────────
  // BE PATCH /api/v1/todos/{id}는 timeConditions 배열을 받으면 deleteAll + saveAll
  // (전체 교체) 한다. 클라에서도 새 배열을 만들어 통째 전송하는 게 깔끔.
  // 가드는 _updateTimeConditions에 모음 — 시간 추가/수정/삭제가 모두 그쪽으로 수렴.

  Future<void> addTimeCondition(TimeConditionRequest tc) async {
    final current = state.detail;
    if (current == null) return;
    final list = [
      ...current.timeConditions.map(TimeConditionRequest.fromCondition),
      tc,
    ];
    await _updateTimeConditions(list);
  }

  Future<void> updateTimeCondition(int index, TimeConditionRequest tc) async {
    final current = state.detail;
    if (current == null) return;
    final list = current.timeConditions
        .map(TimeConditionRequest.fromCondition)
        .toList();
    if (index < 0 || index >= list.length) return;
    list[index] = tc;
    await _updateTimeConditions(list);
  }

  Future<void> removeTimeCondition(int index) async {
    final current = state.detail;
    if (current == null) return;
    final list = current.timeConditions
        .map(TimeConditionRequest.fromCondition)
        .toList();
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _updateTimeConditions(list);
  }

  Future<void> _updateTimeConditions(List<TimeConditionRequest> conditions) async {
    if (_inflight) return;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.update(
        _todoId,
        timeConditions: conditions,
      );
      state = state.copyWith(detail: updated, isLoading: false);
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }

  /// 할 일 본문 인라인 편집 — 상세 페이지의 연필 버튼에서 호출.
  /// content만 변경하므로 슬롯 재계산이 필요 없어 GPS 없이 전송.
  Future<void> updateContent({required String content}) async {
    if (_inflight) return;
    final current = state.detail;
    if (current == null) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed == current.content) return;

    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.update(_todoId, content: trimmed);
      state = state.copyWith(detail: updated, isLoading: false);
      // 목록 화면이 stale content를 보여주지 않도록 invalidate.
      // 뒤로가기 직후 같은 카테고리에 머물러도 새 fetch로 갱신됨.
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }

  /// 키워드로 포괄 장소 등록 — `place_search_screen`의 "포괄 장소로 등록" 버튼에서 호출.
  /// BE PATCH /api/v1/todos/{id}에 placeText만 보내면 BE가 카카오 재검색 + 후보 풀 재구성 + GENERIC 전환.
  Future<void> setGenericKeyword({required String keyword}) async {
    if (_inflight) return;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
      final updated = await _service.update(
        _todoId,
        placeText: keyword,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        course: gps?.course,
        occurredAt: gps?.occurredAt,
      );
      state = state.copyWith(detail: updated, isLoading: false);
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }

  /// 장소 연결 해제
  Future<void> removePlace() async {
    if (_inflight) return;
    _inflight = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _service.removePlace(_todoId);
      state = state.copyWith(detail: updated, isLoading: false);
      ref.invalidate(todoListProvider);
      ref.invalidate(homeRecommendationProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _inflight = false;
    }
  }
}

// ── Provider (todoId별 독립 인스턴스) ─────────────────────────────
final todoDetailProvider =
    NotifierProvider.family<TodoDetailNotifier, TodoDetailState, int>(
  TodoDetailNotifier.new,
);
