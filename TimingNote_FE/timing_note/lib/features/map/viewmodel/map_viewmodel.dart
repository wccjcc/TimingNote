import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../notification/model/geofence_slots.dart';
import '../../notification/service/notification_service.dart';
import '../../todo/model/todo.dart';
import '../../todo/service/todo_service.dart';

/// 지도 위에 실제로 표시할 할 일 위치.
///
/// Todo 목록 응답은 todo당 1개 좌표만 담을 수 있지만, GENERIC은 활성 geofence
/// slot이 여러 개일 수 있다. 지도 탭은 todo가 아니라 "표시 위치" 기준으로
/// 마커를 그려야 하므로 별도 모델로 분리한다.
class MapTodoMarker {
  const MapTodoMarker({
    required this.todo,
    required this.latitude,
    required this.longitude,
    required this.active,
  });

  final TodoItem todo;
  final double latitude;
  final double longitude;
  final bool active;
}

/// 지도 화면 상태.
///
/// todoListProvider와는 분리된 자체 상태 — 목록 화면의 statusFilter/tabFilter 등에
/// 영향받지 않고 항상 "지도용 활성 todo 전체"를 보여준다.
class MapState {
  const MapState({
    this.todos = const [],
    this.activeSlots = const [],
    this.currentGps,
    this.isLoading = false,
    this.error,
    this.activeTypeFilters = const {},
    this.selectedMarkerId,
  });

  final List<TodoItem> todos;
  final List<GeofenceSlotItem> activeSlots;
  final GpsSnapshot? currentGps;
  final bool isLoading;
  final String? error;

  /// 사용자가 칩으로 활성화한 장소 타입들. empty이면 모든 타입 표시.
  /// 예: {TodoType.specific, TodoType.alias}는 특정+내장소만, generic 숨김.
  final Set<String> activeTypeFilters;

  /// 현재 peek 시트에 표시되는 마커 그룹 ID. null이면 시트 닫힘.
  final String? selectedMarkerId;

  /// 필터 적용된 todos — 지도에 표시할 대상.
  /// 정책:
  /// - SPECIFIC/ALIAS: 모두 표시
  /// - GENERIC: activeSlot 또는 active geofence slot이 있는 todo만 표시
  /// - GENERAL/좌표 없음: 자동 제외 (hasPlaceCoords 체크에서)
  /// activeTypeFilters가 비어있으면 위 정책 그대로, 비어있지 않으면 그 타입만 추가 필터.
  List<TodoItem> get filteredTodos {
    final activeSlotTodoIds = activeSlots.map((s) => s.todoId).toSet();
    final base = todos.where((t) {
      // GENERIC은 감지중만 — 후보 풀 전체가 아니라 활성 슬롯에 들어간 것만.
      if (t.todoType == TodoType.generic) {
        return t.activeSlot || activeSlotTodoIds.contains(t.id);
      }
      return true;
    });
    if (activeTypeFilters.isEmpty) return base.toList();
    return base.where((t) => activeTypeFilters.contains(t.todoType)).toList();
  }

  /// 지도에 표시할 실제 위치 목록.
  ///
  /// - SPECIFIC/ALIAS: todo의 primary place 좌표로 표시하고, active slot 유무로
  ///   glow/비활성 상태를 구분한다.
  /// - GENERIC: active geofence slot 좌표만 표시한다. 한 todo가 슬롯 2개에
  ///   들어가면 지도에도 2개 위치로 표시된다.
  List<MapTodoMarker> get markerItems {
    final activeSlotsByTodoId = <int, List<GeofenceSlotItem>>{};
    for (final slot in activeSlots) {
      if (!slot.active || slot.latitude == null || slot.longitude == null) {
        continue;
      }
      (activeSlotsByTodoId[slot.todoId] ??= []).add(slot);
    }

    final items = <MapTodoMarker>[];
    for (final todo in filteredTodos) {
      final slots = activeSlotsByTodoId[todo.id] ?? const <GeofenceSlotItem>[];

      if (todo.todoType == TodoType.generic) {
        for (final slot in slots) {
          items.add(
            MapTodoMarker(
              todo: todo,
              latitude: slot.latitude!,
              longitude: slot.longitude!,
              active: true,
            ),
          );
        }
        continue;
      }

      final active = todo.activeSlot || slots.isNotEmpty;
      if (todo.hasPlaceCoords) {
        items.add(
          MapTodoMarker(
            todo: todo,
            latitude: todo.placeLatitude!,
            longitude: todo.placeLongitude!,
            active: active,
          ),
        );
      } else if (slots.isNotEmpty) {
        // primary 좌표가 비어 있는 오래된 데이터도 active slot 좌표가 있으면 표시한다.
        final slot = slots.first;
        items.add(
          MapTodoMarker(
            todo: todo,
            latitude: slot.latitude!,
            longitude: slot.longitude!,
            active: true,
          ),
        );
      }
    }
    return items;
  }

  /// 좌표 기반 마커 그룹 — 같은 위치(동일 매장)에 여러 todo가 등록되어 있으면 하나의 그룹.
  /// key: "lat,lng" 소수 5자리(~1m 정밀도)로 동일 좌표 매칭.
  Map<String, List<MapTodoMarker>> get markerGroups {
    final groups = <String, List<MapTodoMarker>>{};
    for (final item in markerItems) {
      final key = _coordKey(item.latitude, item.longitude);
      (groups[key] ??= []).add(item);
    }
    return groups;
  }

  /// 시트에 표시할 todo 그룹. selectedMarkerId가 없거나 group이 없으면 빈 리스트.
  List<MapTodoMarker> get selectedGroupTodos {
    final id = selectedMarkerId;
    if (id == null) return const [];
    return markerGroups[id] ?? const [];
  }

  static String _coordKey(double lat, double lng) =>
      '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  MapState copyWith({
    List<TodoItem>? todos,
    List<GeofenceSlotItem>? activeSlots,
    GpsSnapshot? currentGps,
    bool clearGps = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? activeTypeFilters,
    String? selectedMarkerId,
    bool clearSelectedMarker = false,
  }) {
    return MapState(
      todos: todos ?? this.todos,
      activeSlots: activeSlots ?? this.activeSlots,
      currentGps: clearGps ? null : (currentGps ?? this.currentGps),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeTypeFilters: activeTypeFilters ?? this.activeTypeFilters,
      selectedMarkerId: clearSelectedMarker
          ? null
          : (selectedMarkerId ?? this.selectedMarkerId),
    );
  }
}

class MapNotifier extends Notifier<MapState> {
  // Phase 1 정책: 한 번에 충분히 넓게 받아 페이지네이션 안 함.
  // todo 200개면 화면에 마커 200개 — 비주얼 한계 + 응답 ~100KB 정도라 ROI 적정.
  // 200건을 넘는 사용자는 Phase 2에서 클러스터링/페이지네이션 도입.
  static const int _limit = 200;

  late TodoService _service;
  late NotificationService _notificationService;

  @override
  MapState build() {
    _service = ref.read(todoServiceProvider);
    _notificationService = ref.read(notificationServiceProvider);
    Future.microtask(load);
    return const MapState();
  }

  /// 활성 todo(status=ACTIVE) 전체 + 활성 geofence slots + GPS를 병렬로 받아온다.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<Object?>([
        tryGetGpsSnapshot(ref),
        _service.getList(status: TodoStatus.active, limit: _limit),
        _notificationService.getGeofenceSlots(),
      ]);
      final gps = results[0] as GpsSnapshot?;
      final list = results[1] as TodoListResult;
      final slots = results[2] as GeofenceSlotsResponse;
      state = state.copyWith(
        todos: list.items,
        activeSlots: slots.slots,
        isLoading: false,
        currentGps: gps,
        clearGps: gps == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 장소 타입 필터 토글. 동일 타입 다시 누르면 해제.
  void toggleTypeFilter(String type) {
    final current = Set<String>.from(state.activeTypeFilters);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(
      activeTypeFilters: current,
      clearSelectedMarker: true, // 필터 바뀌면 시트 닫음 (그룹이 사라질 수 있음)
    );
  }

  /// 마커 탭 — 해당 좌표 그룹을 시트에 노출.
  void selectMarker(String markerId) {
    state = state.copyWith(selectedMarkerId: markerId);
  }

  void dismissSelection() {
    state = state.copyWith(clearSelectedMarker: true);
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);
