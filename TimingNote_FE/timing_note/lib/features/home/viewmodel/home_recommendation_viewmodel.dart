import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_provider.dart';
import '../../todo/model/todo.dart';
import '../../todo/service/todo_service.dart';
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

  @override
  HomeRecommendationState build() {
    _recommendationService = ref.read(homeRecommendationServiceProvider);
    _todoService = ref.read(todoServiceProvider);
    Future.microtask(load);
    return const HomeRecommendationState();
  }

  Future<void> load() async {
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
        course: gps.course,
      );

      state = state.copyWith(
        isLoading: false,
        items: result.items,
        currentLocationLabel: result.currentLocationLabel,
        currentLatitude: gps.latitude,
        currentLongitude: gps.longitude,
      );
    } catch (e) {
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
    state = state.copyWith(
      items: state.items.where((e) => e.todoId != todoId).toList(),
    );
  }
}

final homeRecommendationProvider =
    NotifierProvider<HomeRecommendationNotifier, HomeRecommendationState>(
      HomeRecommendationNotifier.new,
    );
