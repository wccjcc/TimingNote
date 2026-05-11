import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../model/selected_kakao_place.dart';
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
    final current = state.detail;
    if (current == null) return;

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
    } catch (_) {
      state = state.copyWith(detail: current);
    }
  }

  /// 완료 상태 토글 (낙관적 업데이트) — monitoring 쿼리 필터 변경으로 슬롯 재계산
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
    } catch (_) {
      state = state.copyWith(detail: current);
    }
  }

  /// 소프트 삭제 — 슬롯 비활성화 트리거이므로 GPS 4종 동봉
  Future<bool> deleteTodo() async {
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
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 장소 지정 — ALIAS (내 장소) 선택. GPS 4종은 호출 시점에 가져옴.
  Future<void> setAliasPlace({required int userPlaceId}) async {
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 장소 지정 — SPECIFIC (외부 장소). GPS 4종은 호출 시점에 가져옴.
  Future<void> setExternalPlace({required SelectedExternalPlace place}) async {
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
