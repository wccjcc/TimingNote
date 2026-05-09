import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/status_badge.dart';
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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(todoListProvider.notifier).loadMore();
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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoListProvider);

    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(state.items.length),
              _buildMissionChips(),
              Expanded(child: _buildBody(state)),
            ],
          ),
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

  Widget _buildBody(TodoListState state) {
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
    this.showCategory = true,
  });

  final TodoItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onToggleAlert;
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
                                  _buildRadiusInfo(),
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

  String _buildRadiusInfo() {
    final place = item.resolvedPlaceLabel ?? '행성 탐사 중';
    return '$place (반경 200m)';
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
