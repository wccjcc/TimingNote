import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../model/todo_search_item.dart';
import '../service/todo_search_service.dart';

/// 검색어 입력 → 디바운스(350ms) → API 호출 → 결과/페이지/에러 상태 관리.
///
/// 핵심:
/// - 디바운스로 키 입력 폭주 방지 (입력 멈춘 후 350ms)
/// - 최소 1자부터 검색 시작 (Apple Reminders / Microsoft To Do 패턴)
/// - 카테고리 / placeType 컨텍스트 필터 자동 적용 (todo_list 화면의 현재 탭)
/// - race condition 방지: 새 검색이 들어오면 이전 in-flight 응답은 무시
/// - 무한 스크롤: nextCursor 기반 loadMore
const _debounceMs = 350;
const _minQueryLength = 1;

class SearchState {
  const SearchState({
    required this.query,
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.total,
    this.nextCursor,
    this.error,
    this.category,
    this.placeType,
  });

  final String query;
  final List<TodoSearchItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final int total;
  final String? nextCursor;
  final String? error;

  /// todo_list가 현재 보여주는 카테고리(예: 'DINE'). null이면 전체.
  final String? category;

  /// todo_list의 placeType 필터(예: 'SPECIFIC'). null이면 전체.
  final String? placeType;

  bool get hasMore => nextCursor != null;
  bool get hasError => error != null;

  /// 검색이 활성화된 상태인지 (입력어가 1자 이상).
  bool get isActive => query.isNotEmpty;

  /// 사용자에게 "검색 결과 없음" UI를 보여줄지 판단.
  bool get isEmptyResult =>
      query.length >= _minQueryLength &&
      !isLoading &&
      items.isEmpty &&
      error == null;

  factory SearchState.initial() => const SearchState(
        query: '',
        items: [],
        isLoading: false,
        isLoadingMore: false,
        total: 0,
      );

  SearchState copyWith({
    String? query,
    List<TodoSearchItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    int? total,
    String? nextCursor,
    String? error,
    String? category,
    String? placeType,
    bool clearError = false,
    bool clearCursor = false,
    bool clearCategory = false,
    bool clearPlaceType = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      total: total ?? this.total,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      error: clearError ? null : (error ?? this.error),
      category: clearCategory ? null : (category ?? this.category),
      placeType: clearPlaceType ? null : (placeType ?? this.placeType),
    );
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;
  TodoSearchService? _service;

  /// 가장 최근에 발사된 쿼리. 응답 도착 시 여전히 같은 쿼리인지 비교해 race 방지.
  String? _activeQuery;

  @override
  SearchState build() {
    _service = ref.read(todoSearchServiceProvider);
    ref.onDispose(() => _debounce?.cancel());
    return SearchState.initial();
  }

  /// 사용자가 텍스트필드에 입력할 때마다 호출.
  /// 디바운스 후 실제 검색 실행.
  void setQuery(String raw) {
    final query = raw.trim();
    state = state.copyWith(query: query);
    _debounce?.cancel();

    if (query.length < _minQueryLength) {
      // 검색어 비움 → idle 상태로 회귀, todo_list가 일반 모드로 전환됨
      state = state.copyWith(
        items: const [],
        isLoading: false,
        total: 0,
        clearCursor: true,
        clearError: true,
      );
      _activeQuery = null;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      _search(query);
    });
  }

  /// todo_list의 카테고리 탭 / placeType 필터 변경 시 호출.
  /// 검색 중이면 새 컨텍스트로 즉시 재검색, 아니면 다음 검색에 적용될 컨텍스트만 갱신.
  void setContext({String? category, String? placeType}) {
    final categoryChanged = category != state.category;
    final placeTypeChanged = placeType != state.placeType;
    if (!categoryChanged && !placeTypeChanged) return;

    state = state.copyWith(
      category: category,
      placeType: placeType,
      clearCategory: category == null,
      clearPlaceType: placeType == null,
    );

    if (state.isActive) {
      _debounce?.cancel();
      _search(state.query);
    }
  }

  Future<void> _search(String query) async {
    _activeQuery = query;
    state = state.copyWith(
      isLoading: true,
      items: const [],
      total: 0,
      clearCursor: true,
      clearError: true,
    );

    try {
      final result = await _service!.search(
        q: query,
        category: state.category,
        todoType: state.placeType,
      );
      // race: 응답 도착 시점에 이미 더 새로운 쿼리가 발사됐다면 무시
      if (_activeQuery != query) return;

      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        total: result.total,
        isLoading: false,
      );
    } on ApiException catch (e) {
      if (_activeQuery != query) return;
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (_activeQuery != query) return;
      state = state.copyWith(isLoading: false, error: '검색 중 오류가 발생했어요.');
    }
  }

  /// 무한 스크롤 — 다음 페이지 로드.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    final query = state.query;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final result = await _service!.search(
        q: query,
        cursor: cursor,
        category: state.category,
        todoType: state.placeType,
      );
      // 페이지 로드 중에 사용자가 검색어를 바꿨으면 결과 버림
      if (state.query != query) return;

      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        total: result.total,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      if (state.query != query) return;
      state = state.copyWith(isLoadingMore: false, error: e.message);
    } catch (e) {
      if (state.query != query) return;
      state = state.copyWith(isLoadingMore: false, error: '추가 결과를 불러오지 못했어요.');
    }
  }

  /// 검색 실패 후 재시도.
  Future<void> retry() async {
    if (state.query.length < _minQueryLength) return;
    await _search(state.query);
  }

  /// 검색창 비우기 (X 버튼). 카테고리/placeType 컨텍스트는 유지.
  void clear() {
    _debounce?.cancel();
    _activeQuery = null;
    state = state.copyWith(
      query: '',
      items: const [],
      isLoading: false,
      isLoadingMore: false,
      total: 0,
      clearCursor: true,
      clearError: true,
    );
  }
}
