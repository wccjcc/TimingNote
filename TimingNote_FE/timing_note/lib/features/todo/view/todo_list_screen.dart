import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_distance.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../search/model/todo_search_item.dart';
import '../../search/viewmodel/search_viewmodel.dart';
import '../model/todo.dart';
import '../viewmodel/todo_list_viewmodel.dart';

// -- 카테고리 탭 정의 ----------------------------------------------
const _kCategoryTabs = [
  _CategoryTab(label: '전체', value: null),
  _CategoryTab(label: '식사·카페', value: TodoCategory.dine),
  _CategoryTab(label: '쇼핑·수령', value: TodoCategory.acquire),
  _CategoryTab(label: '병원·운동', value: TodoCategory.health),
  _CategoryTab(label: '은행·관공서', value: TodoCategory.service),
  _CategoryTab(label: '세탁·주유', value: TodoCategory.maintenance),
  _CategoryTab(label: '모임', value: TodoCategory.social),
  _CategoryTab(label: '기타', value: TodoCategory.etc),
];

class _CategoryTab {
  const _CategoryTab({required this.label, required this.value});
  final String label;
  final String? value;
}

class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(
      length: _kCategoryTabs.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 검색 모드면 검색 페이지네이션, 아니면 todoList 페이지네이션
      final searchActive = ref.read(searchProvider).isActive;
      if (searchActive) {
        ref.read(searchProvider.notifier).loadMore();
      } else {
        ref.read(todoListProvider.notifier).loadMore();
      }
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {}); // UI 갱신 (칩 선택 상태 반영)
    final tab = _kCategoryTabs[_tabController.index].value;
    ref.read(todoListProvider.notifier).setFilters(
          tab: tab,
          clearTab: tab == null,
        );
    // 검색 모드면 새 카테고리 컨텍스트로 자동 재검색
    ref.read(searchProvider.notifier).setContext(
          category: tab,
          placeType: ref.read(searchProvider).placeType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoListProvider);
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(state.items.length),
              _buildSearchBar(searchState),
              _buildMissionChips(),
              Expanded(child: _buildBody(state, searchState)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 검색바 (항상 노출) ───────────────────────────────────────────
  Widget _buildSearchBar(SearchState searchState) {
    final hasQuery = searchState.query.isNotEmpty;
    final tabLabel = _kCategoryTabs[_tabController.index].label;
    final placeholder =
        tabLabel == '전체' ? '할 일 검색' : '$tabLabel에서 검색';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasQuery
                ? SpaceColors.neonPurple
                : SpaceColors.neonPurple.withOpacity(0.25),
            width: hasQuery ? 1.5 : 1,
          ),
          boxShadow: hasQuery
              ? [
                  BoxShadow(
                    color: SpaceColors.neonPurple.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: hasQuery
                  ? SpaceColors.neonPurple
                  : SpaceColors.neonPurple.withOpacity(0.6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                cursorColor: SpaceColors.neonPurple,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontFamily: 'Galmuri11',
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    ref.read(searchProvider.notifier).setQuery(v),
              ),
            ),
            if (hasQuery)
              GestureDetector(
                // hit test가 Icon 크기(18x18)보다 작아 미스 클릭이 잦았던 문제 보정.
                // opaque + Padding으로 실제 터치 영역을 ~32x32로 확장.
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchController.clear();
                  ref.read(searchProvider.notifier).clear();
                  _searchFocusNode.unfocus();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(Icons.close,
                      color: Colors.white54, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL: $totalCount',
                style: const TextStyle(
                  color: SpaceColors.neonPurple,
                  fontSize: 10,
                  fontFamily: 'Galmuri11',
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '> 할 일 목록',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Galmuri11',
                  shadows: [Shadow(color: Color(0x7FA78BFA), blurRadius: 10, offset: Offset(0, 4))],
                ),
              ),
            ],
          ),
          _ListIconButton(
            icon: Icons.filter_list,
            onTap: () => _showPlaceFilterMenu(context),
          ),
        ],
      ),
    );
  }

  void _showPlaceFilterMenu(BuildContext context) {
    showMenu<String?>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 24, 0),
      color: SpaceColors.space900,
      items: const [
        PopupMenuItem(value: null, child: Text('모든 할 일', style: TextStyle(color: Colors.white))),
        PopupMenuItem(value: TodoType.specific, child: Text('특정 장소', style: TextStyle(color: Colors.white))),
        PopupMenuItem(value: TodoType.generic, child: Text('포괄적 장소', style: TextStyle(color: Colors.white))),
        PopupMenuItem(value: TodoType.general, child: Text('장소 없음', style: TextStyle(color: Colors.white))),
      ],
    ).then((value) {
      ref.read(todoListProvider.notifier).setFilters(
            placeType: value,
            clearPlaceType: value == null,
          );
      // 검색 모드면 새 placeType 컨텍스트로 자동 재검색
      ref.read(searchProvider.notifier).setContext(
            category: ref.read(searchProvider).category,
            placeType: value,
          );
    });
  }

  Widget _buildMissionChips() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _kCategoryTabs.length,
        itemBuilder: (context, index) {
          final tab = _kCategoryTabs[index];
          final isSelected = _tabController.index == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0x26A78BFA) : const Color(0x992A2A4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? SpaceColors.neonPurple : const Color(0x33A78BFA),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(color: Color(0x66A78BFA), blurRadius: 10),
                          const BoxShadow(color: Color(0xFF581C87), offset: Offset(0, 2)),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tab.label == '전체' ? '전체 할 일' : tab.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0x87A78BFA),
                      fontSize: 11,
                      fontFamily: 'Galmuri11',
                      shadows: isSelected
                          ? [Shadow(offset: const Offset(0, 0), blurRadius: 5, color: SpaceColors.neonPurple.withOpacity(0.8))]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(TodoListState state, SearchState searchState) {
    // 검색 모드: searchProvider 결과를 ListView에 노출 (todoList는 숨김)
    if (searchState.isActive) {
      return _buildSearchBody(searchState);
    }

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: SpaceColors.neonPurple));
    }

    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_late_outlined, size: 60, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('등록된 할 일이 없습니다.', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final activeItems = state.items.where((i) => !i.isDone).toList();
    final doneItems = state.items.where((i) => i.isDone).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(todoListProvider.notifier).load(),
      color: SpaceColors.neonPurple,
      backgroundColor: SpaceColors.space900,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ── 진행 중 섹션 ──
          if (activeItems.isNotEmpty) ...[
            ...activeItems.map((item) => _TodoSpaceTile(
                  item: item,
                  currentGps: state.currentGps,
                  showCategory: _tabController.index == 0, // '전체' 탭일 때만 카테고리 표시
                  onTap: () => context.push('/todos/${item.id}'),
                  onToggleStatus: () => ref.read(todoListProvider.notifier).toggleStatus(item.id),
                  onToggleAlert: () => ref.read(todoListProvider.notifier).toggleAlert(item.id),
                )),
          ],

          // ── 완료된 항목 섹션 ──
          if (doneItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  Expanded(child: Divider(color: SpaceColors.white10)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '완료된 할 일',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontFamily: 'Galmuri11',
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: SpaceColors.white10)),
                ],
              ),
            ),
            ...doneItems.map((item) => _TodoSpaceTile(
                  item: item,
                  currentGps: state.currentGps,
                  showCategory: _tabController.index == 0, // '전체' 탭일 때만 카테고리 표시
                  onTap: () => context.push('/todos/${item.id}'),
                  onToggleStatus: () => ref.read(todoListProvider.notifier).toggleStatus(item.id),
                  onToggleAlert: () => ref.read(todoListProvider.notifier).toggleAlert(item.id),
                )),
          ],

          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 80), // 여백
        ],
      ),
    );
  }
}

class _TodoSpaceTile extends StatelessWidget {
  const _TodoSpaceTile({
    required this.item,
    required this.onTap,
    required this.onToggleStatus,
    required this.onToggleAlert,
    this.currentGps,
    this.showCategory = true,
  });

  final TodoItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onToggleAlert;
  // 마지막으로 알고 있는 사용자 위치 — null이면 거리 표기를 생략하고 라벨만 보여준다.
  final GpsSnapshot? currentGps;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final isDone = item.isDone;
    final categoryKey = item.category ?? TodoCategory.etc;
    final badgeColor = _getCategoryColor(categoryKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDone ? Colors.transparent : const Color(0x991A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? Colors.white10 : const Color(0xFF33334D),
          width: 2,
        ),
        boxShadow: isDone ? null : const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: InkWell(
            onTap: onTap,
            child: Opacity(
              opacity: isDone ? 0.6 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onToggleStatus,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: SpaceColors.space950,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone ? Colors.green : SpaceColors.neonPurple.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: SpaceColors.space900, offset: Offset(0, 3)),
                          ],
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 18, color: Colors.green)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showCategory)
                            StatusBadge(label: TodoCategory.labels[categoryKey] ?? categoryKey, color: badgeColor),
                          const SizedBox(height: 8),
                          Text(
                            item.content,
                            style: TextStyle(
                              color: isDone ? Colors.white38 : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: badgeColor.withOpacity(0.8)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _buildPlaceWithDistance(),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 11,
                                    fontFamily: 'Galmuri11',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (item.thumbnailUrl != null) ...[
                      const SizedBox(width: 12),
                      _buildThumbnailBox(isDone, item.thumbnailUrl!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case TodoCategory.dine:
      case TodoCategory.acquire:
        return SpaceColors.neonPurple;
      case TodoCategory.health:
      case TodoCategory.service:
        return SpaceColors.neonViolet;
      case TodoCategory.maintenance:
        return const Color(0xFFFDBA74);
      case TodoCategory.social:
        return SpaceColors.neonPink;
      default:
        return SpaceColors.neonPurple;
    }
  }

  String _buildPlaceWithDistance() {
    final place = item.resolvedPlaceLabel ?? '행성 탐사 중';
    final gps = currentGps;
    if (gps == null || !item.hasPlaceCoords) {
      return place;
    }
    final meters = haversineMeters(
      gps.latitude,
      gps.longitude,
      item.placeLatitude!,
      item.placeLongitude!,
    );
    return '$place (${formatDistance(meters)})';
  }

  Widget _buildThumbnailBox(bool isDone, String imageUrl) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.3)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDone ? [Colors.transparent, Colors.transparent] : [SpaceColors.white20, SpaceColors.white10],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_outlined,
            size: 20,
            color: isDone ? SpaceColors.white10 : SpaceColors.white20,
          ),
        ),
      ),
    );
  }
}

class _ListIconButton extends StatelessWidget {
  const _ListIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x4CA78BFA)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

// ── 검색 결과 본문 ────────────────────────────────────────────────
extension _TodoListScreenSearch on _TodoListScreenState {
  Widget _buildSearchBody(SearchState searchState) {
    if (searchState.isLoading) {
      return const AppLoadingView(message: '검색 중...', compact: true);
    }
    if (searchState.hasError && searchState.items.isEmpty) {
      return AppErrorView(
        title: '검색 실패',
        message: searchState.error ?? '잠시 후 다시 시도해 주세요.',
        onRetry: () => ref.read(searchProvider.notifier).retry(),
      );
    }
    if (searchState.isEmptyResult) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                '«${searchState.query}» 결과가 없어요.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '다른 키워드로 다시 시도해 보세요.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: searchState.items.length +
          1 + // 결과 헤더
          (searchState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              '«${searchState.query}» 검색 결과 ${searchState.total}건',
              style: const TextStyle(
                color: SpaceColors.neonPurple,
                fontSize: 11,
                fontFamily: 'Galmuri11',
                letterSpacing: 1,
              ),
            ),
          );
        }
        final itemIndex = index - 1;
        if (itemIndex >= searchState.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SpaceColors.neonPurple,
              ),
            ),
          );
        }
        final item = searchState.items[itemIndex];
        return _SearchResultTile(
          item: item,
          onTap: () => context.push('/todos/${item.id}'),
        );
      },
    );
  }
}

/// 검색 결과 한 줄 — 본문 highlight + 매칭 출처 보조 라벨.
///
/// BE 응답의 `highlights` 맵에 들어오는 키별로 다음과 같이 처리:
/// - `content` → 본문에 직접 노랑 강조 (RichText)
/// - `placeLabel` → resolvedPlaceLabel 자리에 RichText로 노랑 강조
/// - `placeName` → 본문에 매칭이 없을 때 "📍 외부 장소: …" 보조 라벨로 표시
///
/// 사용자가 "왜 이 todo가 검색됐는지" 단서를 카드 안에서 즉시 확인 가능.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final TodoSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = item.isDone;
    final categoryKey = item.category ?? TodoCategory.etc;
    final badgeColor = _getCategoryColor(categoryKey);

    final placeLabelHl = item.highlights['placeLabel']?.firstOrNull;
    final placeNameHl = item.highlights['placeName']?.firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0x991A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF33334D)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDone)
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.check_circle_outline,
                          size: 18, color: Colors.green),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.category != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: StatusBadge(
                              label: TodoCategory.labels[categoryKey] ??
                                  categoryKey,
                              color: badgeColor,
                            ),
                          ),
                        // 본문 — content 매칭이 있으면 highlight 자동 적용
                        _HighlightText(
                          html: item.contentHighlight,
                          baseStyle: TextStyle(
                            color: isDone ? Colors.white54 : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            height: 1.4,
                          ),
                          maxLines: 2,
                        ),
                        // 장소 라벨 — placeLabel 매칭이 있으면 그쪽 highlight, 없으면 원문
                        if (item.resolvedPlaceLabel != null &&
                            item.resolvedPlaceLabel!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 12,
                                    color: badgeColor.withOpacity(0.8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _HighlightText(
                                    html: placeLabelHl ??
                                        item.resolvedPlaceLabel!,
                                    baseStyle: TextStyle(
                                      color: badgeColor,
                                      fontSize: 11,
                                      fontFamily: 'Galmuri11',
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 외부 장소명 매칭 — 본문/placeLabel에 검색어 없을 때 단서 제공
                        if (placeNameHl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.travel_explore,
                                    size: 11, color: Colors.white38),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _HighlightText(
                                    html: '외부 장소: $placeNameHl',
                                    baseStyle: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontFamily: 'Galmuri11',
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case TodoCategory.dine:
      case TodoCategory.acquire:
        return SpaceColors.neonPurple;
      case TodoCategory.health:
      case TodoCategory.service:
        return SpaceColors.neonViolet;
      case TodoCategory.maintenance:
        return const Color(0xFFFDBA74);
      case TodoCategory.social:
        return SpaceColors.neonPink;
      default:
        return SpaceColors.neonPurple;
    }
  }
}

/// `<em>...</em>` 마커가 들어있는 fragment를 RichText로 렌더링.
///
/// BE 응답 예시: `"…강남역 <em>약국</em>에서…"`
/// - `<em>` 안쪽: 네온 노랑 + 굵게
/// - 그 외: baseStyle
class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.html,
    required this.baseStyle,
    this.maxLines,
  });

  final String html;
  final TextStyle baseStyle;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final parts = html.split(RegExp(r'<em>|</em>'));
    bool emphasis = false;
    for (final part in parts) {
      if (part.isEmpty) {
        emphasis = !emphasis;
        continue;
      }
      spans.add(TextSpan(
        text: part,
        style: emphasis
            ? baseStyle.copyWith(
                color: SpaceColors.neonYellow,
                fontWeight: FontWeight.w800,
              )
            : null,
      ));
      emphasis = !emphasis;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
