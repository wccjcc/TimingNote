import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../core/location/location_provider.dart';
import '../../todo/model/todo.dart';
import '../../todo/service/todo_service.dart';
import '../../todo/viewmodel/todo_list_viewmodel.dart';
import '../model/home_recommendation.dart';
import '../service/home_recommendation_service.dart';

class HomeRecommendationState {
  const HomeRecommendationState({
    this.items = const <HomeRecommendationItem>[],
    this.currentLocationLabel = '현재 위치',
    this.currentLatitude,
    this.currentLongitude,
    this.isLoading = false,
    this.error,
  });

  final List<HomeRecommendationItem> items;
  final String currentLocationLabel;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool isLoading;
  final String? error;

  HomeRecommendationState copyWith({
    List<HomeRecommendationItem>? items,
    String? currentLocationLabel,
    double? currentLatitude,
    double? currentLongitude,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HomeRecommendationState(
      items: items ?? this.items,
      currentLocationLabel: currentLocationLabel ?? this.currentLocationLabel,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeRecommendationNotifier extends Notifier<HomeRecommendationState> {
  late final HomeRecommendationService _recommendationService;
  late final TodoService _todoService;
  Future<void>? _loadFuture;

  @override
  HomeRecommendationState build() {
    _recommendationService = ref.read(homeRecommendationServiceProvider);
    _todoService = ref.read(todoServiceProvider);
    Future.microtask(load);
    return const HomeRecommendationState();
  }

  Future<void> load() async {
    final runningLoad = _loadFuture;
    if (runningLoad != null) return runningLoad;

    final future = _load();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final gps = await tryGetGpsSnapshot(ref);
      if (gps == null) {
        state = state.copyWith(
          isLoading: false,
          items: const <HomeRecommendationItem>[],
          error: null,
          currentLocationLabel: '현재 위치',
        );
        return;
      }

      final result = await _recommendationService.getRecommendations(
        latitude: gps.latitude,
        longitude: gps.longitude,
        radiusM: 2000,
        course: gps.course,
      );
      debugPrint(
        '[RECO] load success: label=${result.currentLocationLabel}, items=${result.items.length}',
      );

      state = state.copyWith(
        isLoading: false,
        items: result.items,
        currentLocationLabel: result.currentLocationLabel,
        currentLatitude: gps.latitude,
        currentLongitude: gps.longitude,
      );
    } catch (e) {
      debugPrint('[RECO] load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: '추천 정보를 불러오지 못했어요.',
      );
    }
  }

  Future<void> completeTodo(int todoId) async {
    final gps = await tryGetGpsSnapshot(ref, forceFresh: true);
    await _todoService.updateStatus(
      todoId,
      status: TodoStatus.done,
      latitude: gps?.latitude,
      longitude: gps?.longitude,
      course: gps?.course,
      occurredAt: gps?.occurredAt,
    );
    final remaining = state.items.where((e) => e.todoId != todoId).toList();
    final groupCounts = <int, int>{};
    for (final item in remaining) {
      groupCounts[item.groupId] = (groupCounts[item.groupId] ?? 0) + 1;
    }
    final normalized = remaining
        .map(
          (e) => HomeRecommendationItem(
            groupId: e.groupId,
            todoId: e.todoId,
            rank: e.rank,
            todoCount: groupCounts[e.groupId] ?? 0,
            category: e.category,
            title: e.title,
            place: e.place,
            distanceMeters: e.distanceMeters,
            placeLat: e.placeLat,
            placeLng: e.placeLng,
          ),
        )
        .toList();
    state = state.copyWith(items: normalized);
    // 할 일 목록 상태 무효화하여 동기화
    ref.invalidate(todoListProvider);
  }
}

final homeRecommendationProvider =
    NotifierProvider<HomeRecommendationNotifier, HomeRecommendationState>(
      HomeRecommendationNotifier.new,
    );
