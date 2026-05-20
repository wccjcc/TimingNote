import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_message.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/util/show_spring_dialog.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../../shared/widgets/cosmic_background.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/space_card.dart';
import '../../../shared/widgets/space_toast.dart';
import '../../../shared/widgets/status_badge.dart';
import '../model/user_place.dart';
import '../service/user_place_service.dart';
import '../widget/alias_input_sheet.dart';

const int kMyPlacesLimit = 5;

class MyPlacesScreen extends ConsumerStatefulWidget {
  const MyPlacesScreen({super.key});

  @override
  ConsumerState<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

class _MyPlacesScreenState extends ConsumerState<MyPlacesScreen> {
  // 로컬 상태로 목록을 보관 — CRUD 후 전체 reload 없이 부분 갱신(P2)
  // + 삭제 optimistic UI (P1)
  List<UserPlace>? _places;
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final places =
          await ref.read(userPlaceServiceProvider).getUserPlacesStrict();
      if (!mounted) return;
      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final places =
          await ref.read(userPlaceServiceProvider).getUserPlacesStrict();
      if (!mounted) return;
      setState(() {
        _places = places;
      });
    } catch (e) {
      if (!mounted) return;
      SpaceToast.show(
        context,
        message: humanizeApiError(e, action: '새로고침'),
        kind: ToastKind.error,
      );
    }
  }

  // ── Add ─────────────────────────────────────────────────────────────────
  Future<void> _onAddTapped(int currentCount) async {
    if (currentCount >= kMyPlacesLimit) {
      SpaceToast.show(
        context,
        message: '내 장소는 최대 $kMyPlacesLimit개까지 등록할 수 있어요',
        kind: ToastKind.info,
      );
      return;
    }
    final created = await context.push<UserPlace>(
      '/place-search?mode=alias',
    );
    if (!mounted || created == null) return;
    // 신규 항목을 맨 위에 prepend (P2) — "방금 추가" 멘탈 모델
    setState(() {
      final next = [created, ...?_places];
      _places = next;
    });
    // 다른 소비자(Home/TodoInput/UserPlaceSheet) 갱신
    ref.invalidate(userPlacesProvider);
  }

  // ── Rename (PATCH) ──────────────────────────────────────────────────────
  Future<void> _renameAlias(UserPlace place, List<UserPlace> all) async {
    final others = all.where((p) => p.id != place.id).map((p) => p.aliasName);
    final newAlias = await showAliasInputSheet(
      context: context,
      initialAliasName: place.aliasName,
      existingAliases: others,
      placeName: place.placeName,
      placeAddress: place.displayAddress,
    );
    if (newAlias == null || !mounted || newAlias == place.aliasName) return;

    try {
      final updated = await ref.read(userPlaceServiceProvider).updateUserPlace(
            userPlaceId: place.id,
            aliasName: newAlias,
          );
      if (!mounted) return;
      // 로컬 부분 갱신 (P2)
      setState(() {
        _places = _places
            ?.map((p) => p.id == updated.id ? updated : p)
            .toList(growable: false);
      });
      ref.invalidate(userPlacesProvider);
      HapticFeedback.lightImpact(); // P3
      SpaceToast.show(context, message: '별칭이 변경되었어요');
    } catch (e) {
      if (!mounted) return;
      SpaceToast.show(
        context,
        message: humanizeApiError(e, action: '별칭 변경'),
        kind: ToastKind.error,
      );
    }
  }

  // ── Delete (optimistic) ─────────────────────────────────────────────────
  Future<void> _deleteByMenu(UserPlace place) async {
    final confirmed = await _showDeleteConfirm(place);
    if (!confirmed || !mounted) return;
    final list = _places;
    if (list == null) return;
    final originalIndex = list.indexWhere((p) => p.id == place.id);
    if (originalIndex < 0) return;
    setState(() {
      _places = [...list]..removeAt(originalIndex);
    });
    await _deleteOnServer(place, originalIndex);
  }

  Future<void> _deleteOnServer(UserPlace place, int originalIndex) async {
    try {
      await ref.read(userPlaceServiceProvider).deleteUserPlace(place.id);
      if (!mounted) return;
      ref.invalidate(userPlacesProvider);
      HapticFeedback.mediumImpact(); // P3
      SpaceToast.show(context, message: '장소가 삭제되었어요');
    } catch (e) {
      if (!mounted) return;
      // 실패 시 원래 자리에 복원 (P1 롤백)
      setState(() {
        final restored = [...?_places];
        final safeIndex = originalIndex.clamp(0, restored.length);
        restored.insert(safeIndex, place);
        _places = restored;
      });
      SpaceToast.show(
        context,
        message: humanizeApiError(e, action: '삭제'),
        kind: ToastKind.error,
      );
    }
  }

  Future<bool> _showDeleteConfirm(UserPlace place) async {
    final result = await showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SpaceColors.space900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "'${place.aliasName}' 을(를) 삭제할까요?",
            style: const TextStyle(color: SpaceColors.white, fontSize: 16),
          ),
          content: Text(
            '이 장소를 사용 중인 메모가 있다면 알림이 해제될 수 있어요.',
            style: TextStyle(
              color: SpaceColors.neonLavender.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  color: SpaceColors.neonLavender.withValues(alpha: 0.8),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: SpaceColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ⋯ 메뉴 패턴 제거 (2026-05-14) — 시간 조건 카드와 동일하게 카드 탭 + 우측 ✏️ ️/🗑️ 아이콘으로
  // 2뎁스(⋯ → 시트 → 옵션) → 1뎁스(카드/아이콘 탭 → 즉시 액션)로 단축. 액션 3개 이상으로 늘면 ⋯ 복귀 검토.

  // ── Helpers ─────────────────────────────────────────────────────────────
  Color _countBadgeColor(int count) {
    if (count >= kMyPlacesLimit) return SpaceColors.error;
    if (count >= kMyPlacesLimit - 2) return SpaceColors.neonYellow;
    return SpaceColors.neonLavender;
  }


  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isInitialLoading = _isLoading && _places == null;
    final hasInitialError = _loadError != null && _places == null;
    final places = _places ?? const <UserPlace>[];

    return Scaffold(
      backgroundColor: SpaceColors.space950,
      body: CosmicBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: SpaceColors.neonPurple,
            backgroundColor: SpaceColors.space900,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildAppBar(places.length, showCount: !isInitialLoading),
                ),
                _buildSliverBody(
                  isInitialLoading: isInitialLoading,
                  hasInitialError: hasInitialError,
                  places: places,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(int count, {required bool showCount}) {
    final canAdd = showCount && count < kMyPlacesLimit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SpaceColors.white,
              size: 18,
            ),
          ),
          const Text(
            '내 장소',
            style: TextStyle(
              fontFamily: SpaceTypography.pixelFontFamily,
              fontSize: 18,
              color: SpaceColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (showCount)
            StatusBadge(
              label: '$count / $kMyPlacesLimit',
              color: _countBadgeColor(count),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: canAdd ? () => _onAddTapped(count) : null,
            icon: Icon(
              Icons.add_circle_outline,
              color: canAdd ? SpaceColors.neonLavender : SpaceColors.white20,
              size: 26,
            ),
            tooltip: '내 장소 추가',
          ),
        ],
      ),
    );
  }

  Widget _buildSliverBody({
    required bool isInitialLoading,
    required bool hasInitialError,
    required List<UserPlace> places,
  }) {
    if (isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppLoadingView(message: '내 장소를 불러오는 중...'),
      );
    }
    if (hasInitialError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(
          title: '내 장소를 불러오지 못했어요',
          onRetry: _loadInitial,
        ),
      );
    }
    if (places.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          alignment: Alignment.center,
          child: _EmptyState(onAdd: () => _onAddTapped(0)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == places.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '최대 $kMyPlacesLimit개까지 등록할 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SpaceTypography.pixelFontFamily,
                    fontSize: 11,
                    color: SpaceColors.neonLavender.withValues(alpha: 0.4),
                  ),
                ),
              );
            }
            final place = places[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlaceCard(
                place: place,
                indexHint: index,
                onEditTap: () => _renameAlias(place, places),
                onDeleteTap: () => _deleteByMenu(place),
              ),
            );
          },
          childCount: places.length + 1,
        ),
      ),
    );
  }

}

/// 내 장소 카드 — 카드 탭/우측 ✏️ 모두 별칭 변경, 우측 🗑️는 삭제.
/// 카드를 누르는 순간 "수정 모드 진입" 시그널을 강하게 주기 위해 복합 시각 효과:
/// - 카드 외곽 보라 글로우 boost (boxShadow)
/// - SpaceCard border 색 white12 → neonPurple 진해짐
/// - ✏️ 아이콘 색 white54 → neonPurple + scale 1.0 → 1.15
/// - 전체 카드 scale 0.97 (TapBounce 효과 통합)
/// 모두 동시에 발동해 "이 카드를 누르면 편집이 시작된다"를 명확히 전달.
class _PlaceCard extends StatefulWidget {
  const _PlaceCard({
    required this.place,
    required this.indexHint,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final UserPlace place;
  final int indexHint;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard>
    with SingleTickerProviderStateMixin {
  // 누름 효과를 AnimationController로 — 빠른 탭에서도 최소 forward 완료까지 강조 보장.
  // boolean setState 기반은 down→up이 50ms 안에 끝나는 빠른 탭에서 transition이
  // 시작도 안 한 채 reset돼 효과가 거의 안 보이는 문제 발생.
  late final AnimationController _press;
  Future<void>? _forwardFuture;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),  // 강해지는 시간
      reverseDuration: const Duration(milliseconds: 260), // 사그라드는 시간 (조금 더 길게)
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  IconData get _icon =>
      widget.indexHint == 0 ? Icons.home_outlined : Icons.place_outlined;
  Color get _iconColor =>
      widget.indexHint == 0 ? SpaceColors.neonLavender : SpaceColors.neonViolet;

  void _onTapDown(_) {
    _forwardFuture = _press.forward();
  }

  Future<void> _onTapUp(_) async {
    // 빠른 탭: forward가 끝나기 전 onTapUp이 와도 forward 완료까지 기다린 후 reverse.
    // → 짧은 탭에서도 효과가 최소 440ms 동안 보임 (forward 180 + reverse 260).
    await _forwardFuture;
    if (mounted) _press.reverse();
  }

  Future<void> _onTapCancel() async {
    await _forwardFuture;
    if (mounted) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onEditTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          // easeOut으로 곡선 — peak가 빠르게 도달.
          final t = Curves.easeOut.transform(_press.value);
          final cardScale = 1.0 - 0.03 * t;          // 1.0 → 0.97
          final iconScale = 1.0 + 0.18 * t;          // 1.0 → 1.18
          final iconColor = Color.lerp(
                Colors.white54,
                SpaceColors.neonPurple,
                t,
              ) ??
              Colors.white54;
          final borderColor = Color.lerp(
                SpaceColors.white.withValues(alpha: 0.12),
                SpaceColors.neonPurple.withValues(alpha: 0.7),
                t,
              );

          return Transform.scale(
            scale: cardScale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                // 누름 강도에 비례한 글로우 — peak에서 보라 빛이 외곽으로 퍼짐.
                boxShadow: t > 0.01
                    ? [
                        BoxShadow(
                          color: SpaceColors.neonPurple
                              .withValues(alpha: 0.45 * t),
                          blurRadius: 18 * t,
                          spreadRadius: 1 * t,
                        ),
                      ]
                    : null,
              ),
              child: SpaceCard(
                padding: const EdgeInsets.all(14),
                borderColor: borderColor,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: SpaceColors.space800,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _iconColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(_icon, size: 20, color: _iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.place.aliasName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: SpaceTypography.pixelFontFamily,
                              color: SpaceColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.place.placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SpaceColors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.place.displayAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: SpaceColors.neonLavender
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ✏️ — 누름 진행도 t에 따라 색 + scale 동시 강조.
                    IconButton(
                      onPressed: widget.onEditTap,
                      tooltip: '수정',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Transform.scale(
                        scale: iconScale,
                        child: Icon(
                          Icons.edit_outlined,
                          color: iconColor,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: widget.onDeleteTap,
                      tooltip: '삭제',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SpaceColors.neonPurple.withValues(alpha: 0.1),
                border: Border.all(
                  color: SpaceColors.neonPurple.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.location_searching,
                color: SpaceColors.neonLavender,
                size: 38,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '별칭으로 등록된 장소가 없어요',
              style: TextStyle(
                fontFamily: SpaceTypography.pixelFontFamily,
                fontSize: 15,
                color: SpaceColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "자주 가는 곳을 별칭으로 등록해보세요\n예: '집', '회사', '단골카페'",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: SpaceColors.neonLavender.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: NeonButton(
                label: '처음 등록하기',
                icon: Icons.add,
                onTap: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
