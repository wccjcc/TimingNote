import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_distance.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/util/navigation_guard.dart';
import '../../../../shared/widgets/animated_list_entry.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/tap_bounce.dart';
import '../../search/model/todo_search_item.dart';
import '../../search/viewmodel/search_viewmodel.dart';
import '../model/todo.dart';
import '../util/todo_type_style.dart';
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
    with SingleTickerProviderStateMixin, NavigationGuardMixin<TodoListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final TabController _tabController;

  /// 빠른 더블 탭으로 같은 상세 화면이 두 번 push되는 것을 방지.
  void _openDetail(int todoId) {
    guardedRunSync(() => context.push('/todos/$todoId'));
  }

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
          child: RefreshIndicator(
            onRefresh: () => ref.read(todoListProvider.notifier).load(),
            color: SpaceColors.neonPurple,
            backgroundColor: SpaceColors.space900,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    state.items.length,
                    state.placeTypeFilter,
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchBar(searchState)),
                SliverToBoxAdapter(child: _buildMissionChips()),
                _buildSliverBody(state, searchState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 검색바 (항상 노출) ───────────────────────────────────────────
  Widget _buildSearchBar(SearchState searchState) {
    final hasQuery = searchState.query.isNotEmpty;
    final tabLabel = _kCategoryTabs[_tabController.index].label;
    final placeholder = tabLabel == '전체' ? '할 일 검색' : '$tabLabel에서 검색';

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
                onChanged: (v) => ref.read(searchProvider.notifier).setQuery(v),
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
                  child: Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalCount, String? activePlaceType) {
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
                  shadows: [
                    Shadow(
                      color: Color(0x7FA78BFA),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _PlaceTypeFilterMenu(
            activePlaceType: activePlaceType,
            onChanged: (value) {
              ref.read(todoListProvider.notifier).setFilters(
                    placeType: value,
                    clearPlaceType: value == null,
                  );
              // 검색 모드면 새 placeType 컨텍스트로 자동 재검색
              ref.read(searchProvider.notifier).setContext(
                    category: ref.read(searchProvider).category,
                    placeType: value,
                  );
            },
          ),
        ],
      ),
    );
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
                // 같은 탭 재탭 시 animateTo는 0-duration animation을 발사하면서도
                // listener를 1회 호출 → setFilters → BE 재호출(스타일상 "새로고침")이
                // 발생함. 같은 index면 noop으로 차단.
                if (_tabController.index != index) {
                  _tabController.animateTo(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0x26A78BFA)
                      : const Color(0x992A2A4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? SpaceColors.neonPurple
                        : const Color(0x33A78BFA),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                            color: Color(0x66A78BFA),
                            blurRadius: 10,
                          ),
                          const BoxShadow(
                            color: Color(0xFF581C87),
                            offset: Offset(0, 2),
                          ),
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
                          ? [
                              Shadow(
                                offset: const Offset(0, 0),
                                blurRadius: 5,
                                color: SpaceColors.neonPurple.withOpacity(0.8),
                              ),
                            ]
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

  Widget _buildSliverBody(TodoListState state, SearchState searchState) {
    if (searchState.isActive) {
      return _buildSearchSliverBody(searchState);
    }

    if (state.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: SpaceColors.neonPurple),
        ),
      );
    }

    if (state.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                size: 60,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              const Text(
                '등록된 할 일이 없습니다.',
                style: TextStyle(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    final activeItems = state.items.where((i) => !i.isDone).toList();
    final doneItems = state.items.where((i) => i.isDone).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── 진행 중 섹션 ──
          if (activeItems.isNotEmpty) ...[
            for (var i = 0; i < activeItems.length; i++)
              AnimatedListEntry(
                index: i,
                child: _TodoSpaceTile(
                  item: activeItems[i],
                  currentGps: state.currentGps,
                  showCategory: _tabController.index == 0,
                  onTap: () => _openDetail(activeItems[i].id),
                  onToggleStatus: () => ref
                      .read(todoListProvider.notifier)
                      .toggleStatus(activeItems[i].id),
                  onToggleAlert: () => ref
                      .read(todoListProvider.notifier)
                      .toggleAlert(activeItems[i].id),
                ),
              ),
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
            for (var i = 0; i < doneItems.length; i++)
              AnimatedListEntry(
                index: activeItems.length + i,
                child: _TodoSpaceTile(
                  item: doneItems[i],
                  currentGps: state.currentGps,
                  showCategory: _tabController.index == 0,
                  onTap: () => _openDetail(doneItems[i].id),
                  onToggleStatus: () => ref
                      .read(todoListProvider.notifier)
                      .toggleStatus(doneItems[i].id),
                  onToggleAlert: () => ref
                      .read(todoListProvider.notifier)
                      .toggleAlert(doneItems[i].id),
                ),
              ),
          ],

          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 80),
        ]),
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
  /// 마지막으로 알고 있는 사용자 위치 — null이면 거리 표기를 생략하고 라벨만 보여준다.
  final GpsSnapshot? currentGps;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final isDone = item.isDone;
    final categoryKey = item.category ?? TodoCategory.etc;
    final badgeColor = _getCategoryColor(categoryKey);

    // 카드 최외곽을 TapBounce로 감싸 누를 때 살짝 줄어들고 spring으로 복귀.
    // 다크 톤이라 Material ripple은 잘 안 보임 → InkWell 대신 scale로 통일.
    return TapBounce(
      onTap: onTap,
      child: Container(
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (showCategory)
                                StatusBadge(label: TodoCategory.labels[categoryKey] ?? categoryKey, color: badgeColor),
                              StatusBadge(
                                label: TodoType.labelOf(item.todoType),
                                color: todoTypeColor(item.todoType),
                              ),
                            ],
                          ),
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
                          if (_buildPlaceLine() != null)
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: badgeColor.withOpacity(0.8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _buildPlaceLine()!,
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

  /// 장소 라벨 + (가능하면) 현재 위치로부터의 거리.
  ///
  /// - 장소 라벨도 좌표도 없으면 null → 위치 줄 자체를 숨김
  /// - 라벨만 있고 좌표/GPS 없음 → 라벨만 표시 ("메가커피")
  /// - 라벨 + 좌표 + GPS 모두 있음 → "메가커피 · 350m"
  String? _buildPlaceLine() {
    final label = item.resolvedPlaceLabel;
    final gps = currentGps;

    final distance = (item.hasPlaceCoords && gps != null)
        ? formatDistance(haversineMeters(
            gps.latitude,
            gps.longitude,
            item.placeLatitude!,
            item.placeLongitude!,
          ))
        : null;

    if (label == null && distance == null) return null;
    if (label == null) return distance;
    if (distance == null) return label;
    return '$label · $distance';
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

// ── 장소 타입 필터 드롭다운 ──────────────────────────────────────────
/// 헤더 우측 필터 버튼 → 카테고리 드롭다운(`_CategoryDropdown` in todo_edit)과 동일 톤.
/// - 활성 필터 시 트리거 색이 보라 글로우 + 작은 점 노출 → "필터 적용 중" 시그널
/// - 메뉴는 `MenuAnchor` 기반으로 트리거 아래로 라운드 박스 펼침
/// - 선택 항목은 보라 10% 배경 + check 아이콘 + neonPurple 글자
class _PlaceTypeFilterMenu extends StatelessWidget {
  const _PlaceTypeFilterMenu({
    required this.activePlaceType,
    required this.onChanged,
  });

  /// null이면 전체(필터 없음), 그 외 TodoType 상수.
  final String? activePlaceType;
  final ValueChanged<String?> onChanged;

  static const List<({String? value, String label})> _items = [
    (value: null, label: '모든 할 일'),
    (value: TodoType.specific, label: '특정 장소'),
    (value: TodoType.generic, label: '포괄적 장소'),
    (value: TodoType.general, label: '장소 없음'),
  ];

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = activePlaceType != null;

    return MenuAnchor(
      // 트리거 우측 끝에서 아래로 살짝 떨어뜨려 펼침
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xE50F0F1A)),
        elevation: const WidgetStatePropertyAll(8),
        // padding을 EdgeInsets.zero로 두어 첫/마지막 항목의 선택 배경이 메뉴
        // 외곽 라운드 경계까지 닿게 한다. 기존 vertical:4가 빈 공간을 만들었음.
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: SpaceColors.neonPurple.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
      menuChildren: _items.asMap().entries.map((entry) {
        final i = entry.key;
        final it = entry.value;
        final selected = it.value == activePlaceType;
        // 카테고리 드롭다운과 동일한 stagger entrance.
        // MenuAnchor가 메뉴 표시마다 OverlayPortal에 새 위젯을 띄우니
        // 매번 initState 발동 → stagger가 매번 보임.
        return AnimatedListEntry(
          index: i,
          delayPerItem: const Duration(milliseconds: 45),
          duration: const Duration(milliseconds: 220),
          offsetY: 10,
          child: MenuItemButton(
            onPressed: () => onChanged(it.value),
            style: MenuItemButton.styleFrom(
              foregroundColor: selected ? SpaceColors.neonPurple : Colors.white,
              backgroundColor: selected
                  ? SpaceColors.neonPurple.withValues(alpha: 0.10)
                  : null,
              // 텍스트가 메뉴 외곽에 답답하게 붙지 않도록 padding 확장
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              minimumSize: const Size(180, 0),
            ),
            trailingIcon: selected
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: SpaceColors.neonPurple,
                  )
                : null,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                it.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
      builder: (context, controller, _) {
        return GestureDetector(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // 활성 필터 시 보라 배경/border 진해짐 — "필터 적용 중" 시그널
              color: hasActiveFilter
                  ? SpaceColors.neonPurple.withValues(alpha: 0.18)
                  : const Color(0xFF2A2A4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveFilter
                    ? SpaceColors.neonPurple.withValues(alpha: 0.6)
                    : const Color(0x4CA78BFA),
                width: hasActiveFilter ? 1.5 : 1.0,
              ),
              boxShadow: hasActiveFilter
                  ? [
                      BoxShadow(
                        color: SpaceColors.neonPurple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.filter_list,
                  color: hasActiveFilter
                      ? SpaceColors.neonPurple
                      : Colors.white70,
                  size: 20,
                ),
                // 활성 필터 시 우상단 작은 보라 점 — 추가 시각 신호
                if (hasActiveFilter)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: SpaceColors.neonPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SpaceColors.neonPurple,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 검색 결과 본문 ────────────────────────────────────────────────
extension _TodoListScreenSearch on _TodoListScreenState {
  Widget _buildSearchSliverBody(SearchState searchState) {
    if (searchState.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppLoadingView(message: '검색 중...', compact: true),
      );
    }
    if (searchState.hasError && searchState.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(
          title: '검색 실패',
          message: searchState.error ?? '잠시 후 다시 시도해 주세요.',
          onRetry: () => ref.read(searchProvider.notifier).retry(),
        ),
      );
    }
    if (searchState.isEmptyResult) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
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
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
              onTap: () => _openDetail(item.id),
            );
          },
          childCount: searchState.items.length +
              1 +
              (searchState.isLoadingMore ? 1 : 0),
        ),
      ),
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
