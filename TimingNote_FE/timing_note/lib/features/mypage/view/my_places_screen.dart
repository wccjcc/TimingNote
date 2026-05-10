import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_message.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
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

const int kMyPlacesLimit = 10;

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
    final result = await showDialog<bool>(
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

  // ── ⋯ menu ──────────────────────────────────────────────────────────────
  Future<void> _onMoreTapped(UserPlace place, List<UserPlace> all) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpaceColors.space900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit,
                  color: SpaceColors.neonLavender,
                ),
                title: const Text(
                  '별칭 변경',
                  style: TextStyle(color: SpaceColors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: SpaceColors.error,
                ),
                title: const Text(
                  '삭제',
                  style: TextStyle(color: SpaceColors.error),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    switch (result) {
      case 'edit':
        await _renameAlias(place, all);
        break;
      case 'delete':
        await _deleteByMenu(place);
        break;
    }
  }

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
          child: Column(
            children: [
              _buildAppBar(places.length, showCount: !isInitialLoading),
              Expanded(
                child: _buildBody(
                  isInitialLoading: isInitialLoading,
                  hasInitialError: hasInitialError,
                  places: places,
                ),
              ),
            ],
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
              color: canAdd
                  ? SpaceColors.neonLavender
                  : SpaceColors.white20,
              size: 26,
            ),
            tooltip: '내 장소 추가',
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool isInitialLoading,
    required bool hasInitialError,
    required List<UserPlace> places,
  }) {
    if (isInitialLoading) {
      return const AppLoadingView(message: '내 장소를 불러오는 중...');
    }
    if (hasInitialError) {
      return AppErrorView(
        title: '내 장소를 불러오지 못했어요',
        onRetry: _loadInitial,
      );
    }
    if (places.isEmpty) {
      return _EmptyState(onAdd: () => _onAddTapped(0));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: SpaceColors.neonPurple,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: places.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
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
          return Dismissible(
            key: ValueKey('user-place-${place.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _showDeleteConfirm(place),
            onDismissed: (_) => _onSwipeDismissed(place),
            background: _DismissBackground(),
            child: _PlaceCard(
              place: place,
              indexHint: index,
              onMoreTap: () => _onMoreTapped(place, places),
            ),
          );
        },
      ),
    );
  }

  // Swipe로 dismiss된 직후 호출 — 카드는 이미 화면에서 사라진 상태
  void _onSwipeDismissed(UserPlace place) {
    final list = _places;
    if (list == null) return;
    final originalIndex = list.indexWhere((p) => p.id == place.id);
    if (originalIndex < 0) return;
    setState(() {
      _places = [...list]..removeAt(originalIndex);
    });
    _deleteOnServer(place, originalIndex);
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.indexHint,
    required this.onMoreTap,
  });

  final UserPlace place;
  final int indexHint;
  final VoidCallback onMoreTap;

  IconData get _icon =>
      indexHint == 0 ? Icons.home_outlined : Icons.place_outlined;
  Color get _iconColor =>
      indexHint == 0 ? SpaceColors.neonLavender : SpaceColors.neonViolet;

  @override
  Widget build(BuildContext context) {
    return SpaceCard(
      padding: const EdgeInsets.all(14),
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
                    place.aliasName,
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
                    place.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpaceColors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.displayAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: SpaceColors.neonLavender.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMoreTap,
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                // P8: alpha 0.5 → 0.75 — 묻혀 보이는 문제 해소
                color: SpaceColors.neonLavender.withValues(alpha: 0.75),
              ),
              tooltip: '메뉴',
            ),
          ],
        ),
      );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: SpaceColors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SpaceColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: SpaceColors.error, size: 22),
          SizedBox(width: 6),
          Text(
            '삭제',
            style: TextStyle(
              color: SpaceColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
