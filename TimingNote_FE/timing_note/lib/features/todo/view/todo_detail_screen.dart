import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_distance.dart';
import '../../../core/location/location_provider.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/cosmic_background.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/space_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../model/selected_kakao_place.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../model/todo_detail.dart';
import '../util/time_condition_formatter.dart';
import '../util/todo_type_style.dart';
import '../viewmodel/todo_detail_viewmodel.dart';
import '../widgets/native_kakao_map.dart';
import 'todo_edit_screen.dart' show TimeConditionEditSheet;

class TodoDetailScreen extends ConsumerWidget {
  const TodoDetailScreen({super.key, required this.todoId});

  final int todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todoDetailProvider(todoId));

    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: state.error != null
              ? _buildErrorView(ref, state.error!)
              : state.detail == null
              // 상세 데이터는 Future.microtask(load)로 다음 이벤트 루프에서 가져옵니다.
              // 첫 프레임에는 detail이 아직 null일 수 있으므로 로딩 화면을 먼저 보여줍니다.
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SpaceColors.neonPurple,
                  ),
                )
              : _buildMainContent(context, ref, state.detail!, state.currentGps),
        ),
      ),
    );
  }

  Widget _buildErrorView(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '오류 발생: $error',
            style: const TextStyle(color: SpaceColors.white50),
          ),
          const SizedBox(height: 16),
          NeonButton(
            label: '다시 시도',
            onTap: () => ref.read(todoDetailProvider(todoId).notifier).load(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    TodoDetail detail,
    GpsSnapshot? currentGps,
  ) {
    final categoryKey = detail.category ?? TodoCategory.etc;
    final themeColor = _getCategoryColor(categoryKey);

    return Column(
      children: [
        // 1. 헤더 (뒤로가기, 타이틀, 수정, 삭제)
        _buildHeader(context, ref, detail),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(todoDetailProvider(todoId).notifier).load(),
            color: SpaceColors.neonPurple,
            backgroundColor: SpaceColors.space900,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              children: [
                // 2. 상태 배너 (분석 중일 때만)
                if (detail.isPending) _SpacePendingBanner(),

                // 3. 상단 요약 정보 (카테고리 + 장소 타입 + 상태)
                Row(
                  children: [
                    StatusBadge(
                      label: TodoCategory.labels[categoryKey] ?? categoryKey,
                      color: themeColor,
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: TodoType.labelOf(detail.todoType),
                      color: todoTypeColor(detail.todoType),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      detail.isDone ? '완료됨' : '진행 중',
                      style: TextStyle(
                        color: detail.isDone
                            ? SpaceColors.success
                            : SpaceColors.neonPurple,
                        fontSize: 12,
                        fontFamily: SpaceTypography.pixelFontFamily,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. 할 일 본문 (가장 크게 표시) + 인라인 편집 버튼
                // 수정 페이지 진입 없이 본문만 즉시 수정. 슬롯 재계산이 없어 GPS 미사용.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        detail.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _InlineEditButton(
                      onTap: () => _openContentEditSheet(context, ref, detail),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '등록일: ${_formatDate(detail.createdAt)}',
                  style: const TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 13,
                  ),
                ),

                // 5. 시각 자료 (첨부 이미지) — 본문 직하단으로 이동.
                // 시각 컨텍스트를 먼저 인식 → 그 다음 실행 조건(장소/시간) 박스로 시선 이동.
                if (detail.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '첨부 이미지'),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _ImageThumbnail(
                        imageUrls: detail.imageUrls,
                        initialIndex: i,
                      ),
                    ),
                  ),
                ],

                // 6. 공유 링크 (OG 프리뷰 카드) — 이미지 아래.
                // 메모/할 일에 붙은 URL을 카카오톡/슬랙 스타일 카드(썸네일·제목·도메인)로 표시.
                // 카드 자체 탭 → 외부 브라우저로 열림 (any_link_preview 내장).
                if (detail.sharedUrl != null &&
                    detail.sharedUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(title: '공유 링크'),
                  _SharedLinkCard(url: detail.sharedUrl!.trim()),
                ],

                const SizedBox(height: 28),

                // 6. 조건 정보 섹션 (장소, 시간)
                _buildInfoSection(context, ref, detail, themeColor),

                const SizedBox(height: 24),

                // GENERIC만 후보 섹션을, 그 외(SPECIFIC/ALIAS)는 primaryPlace 단일 표시.
                // ALIAS는 등록 시 후보가 1건만 들어가지만 의미상 primaryPlace와 동일하므로
                // 후보 섹션 노출 시 정보 중복(같은 장소가 카드+후보로 두 번) + distanceM=0 stale 표시 발생.
                if (detail.todoType == TodoType.generic &&
                    detail.candidates.isNotEmpty) ...[
                  // 7. GENERIC 후보 장소 — 미니 지도 + 카드 리스트
                  _CandidateSection(todoId: detail.id, candidates: detail.candidates),
                  const SizedBox(height: 24),
                ] else if (detail.primaryPlace != null) ...[
                  // 7. SPECIFIC/ALIAS 단일 장소 — 일관성: [지도 → 카드] 순
                  // primaryPlaceId 매칭 후보로 감지중/대기 상태 + 마커 색을 동기화한다.
                  // SPECIFIC 등록 후보 저장 통일(2026-05-13) 이후 매칭 1건이 보장된 케이스 + null fallback.
                  if (detail.primaryPlace!.latitude != null &&
                      detail.primaryPlace!.longitude != null) ...[
                    _PrimaryPlaceMap(
                      place: detail.primaryPlace!,
                      primaryCandidate: _findPrimaryCandidate(detail),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildPlaceDetailCard(
                    detail.primaryPlace!,
                    currentGps,
                    _findPrimaryCandidate(detail),
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // 8. 하단 액션 버튼
        _buildBottomActions(ref, detail),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, TodoDetail? detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          const Text(
            '할 일 상세',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: SpaceTypography.pixelFontFamily,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => context.push('/todos/$todoId/edit'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: SpaceColors.white50,
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceColors.space900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SpaceColors.white10),
        ),
        title: const Text(
          '할 일 삭제',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '이 할 일을 삭제할까요?\n삭제된 항목은 복구할 수 없습니다.',
          style: TextStyle(
            color: SpaceColors.white50,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(color: SpaceColors.white50),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: SpaceColors.neonPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final ok = await ref.read(todoDetailProvider(todoId).notifier).deleteTodo();
    if (ok && context.mounted) context.pop();
  }

  Widget _buildInfoSection(
    BuildContext context,
    WidgetRef ref,
    TodoDetail detail,
    Color color,
  ) {
    return SpaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 장소 정보
          Row(
            children: [
              Icon(Icons.location_on, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '실행 장소',
                      style: TextStyle(
                        color: SpaceColors.white50,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.resolvedPlaceLabel ?? '장소 미정',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // 장소 빠른 수정 버튼
              GestureDetector(
                onTap: () => _onEditPlaceTap(context, ref, detail),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SpaceColors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SpaceColors.white10),
                  ),
                  child: const Icon(
                    Icons.edit_location_alt_outlined,
                    color: SpaceColors.neonPurple,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: SpaceColors.white10, height: 1),
          ),
          // 시간 정보 — 옵션 B (Mini-card per condition + type badge + 추가/수정/삭제)
          Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Colors.cyanAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '실행 시간',
                style: TextStyle(color: SpaceColors.white50, fontSize: 11),
              ),
              const Spacer(),
              // 시간 추가 — 상세 화면에서 직접 Sheet 호출, BE PATCH로 즉시 반영.
              // 실행장소 수정 박스(padding 6, icon 16)와 동일 사이즈로 정사각화.
              // 색은 시간 의미상 cyan 유지.
              GestureDetector(
                onTap: () => _openAddTimeSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.cyanAccent,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (detail.timeConditions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                '시간 조건 없음',
                style: TextStyle(
                  color: SpaceColors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            )
          else
            Column(
              children: List.generate(detail.timeConditions.length, (i) {
                final tc = detail.timeConditions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TimeConditionCard(
                    condition: tc,
                    onTap: () => _openEditTimeSheet(context, ref, i, tc),
                    onDelete: () => _confirmDeleteTime(context, ref, i, tc),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  /// SPECIFIC/ALIAS 단일 장소 정보 카드 — GENERIC _CandidateCard와 시각 톤 통일.
  /// 감지중/대기 배지 + 가게명 + 거리(오른쪽) + 도로명.
  ///
  /// [primaryCandidate]는 detail.candidates에서 primaryPlaceId 매칭으로 찾은 항목.
  /// 있으면 activeSlot으로 감지중 여부 표시, 없으면 '대기'로 fallback.
  Widget _buildPlaceDetailCard(
    TodoPlace place,
    GpsSnapshot? gps,
    TodoCandidate? primaryCandidate,
  ) {
    final activeSlot = primaryCandidate?.activeSlot ?? false;
    final activeColor =
        activeSlot ? SpaceColors.success : SpaceColors.white50;
    final activeLabel = activeSlot ? '감지중' : '대기';
    final distanceLabel = _placeDistanceLabel(place, gps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceColors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeSlot
              ? SpaceColors.success.withOpacity(0.4)
              : SpaceColors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CandidateBadge(label: activeLabel, color: activeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distanceLabel != null)
                Text(
                  distanceLabel,
                  style: const TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (place.roadAddress != null) ...[
            const SizedBox(height: 6),
            Text(
              place.roadAddress!,
              style: TextStyle(
                color: SpaceColors.white.withOpacity(0.6),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// primaryPlaceId와 매칭되는 candidate를 찾는다. activeSlot/모니터링 상태가 필요할 때 사용.
  /// SPECIFIC 등록 후보 저장 통일(2026-05-13) 이후 항상 1건 존재가 기대값.
  /// 잔여 케이스(과거 데이터·BE 불일치)에는 null로 떨어져 카드/마커가 '대기'·비활성으로 fallback.
  TodoCandidate? _findPrimaryCandidate(TodoDetail detail) {
    final pid = detail.primaryPlace?.id;
    if (pid == null) return null;
    for (final c in detail.candidates) {
      if (c.place.id == pid) return c;
    }
    return null;
  }

  /// 사용자 현재 위치와 장소 좌표 둘 다 있을 때만 "350m" / "1.2km" 라벨을 만든다.
  /// 없으면 null → 호출처에서 줄 자체를 숨김. 거리 유틸은 목록 화면과 공용.
  String? _placeDistanceLabel(TodoPlace place, GpsSnapshot? gps) {
    final lat = place.latitude;
    final lng = place.longitude;
    if (lat == null || lng == null || gps == null) return null;
    return formatDistance(
        haversineMeters(gps.latitude, gps.longitude, lat, lng));
  }

  Widget _buildBottomActions(WidgetRef ref, TodoDetail detail) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: SpaceColors.space900,
        border: Border(top: BorderSide(color: SpaceColors.white10)),
      ),
      child: Row(
        children: [
          _CircleActionButton(
            icon: detail.alertEnabled
                ? Icons.notifications
                : Icons.notifications_off,
            onTap: () =>
                ref.read(todoDetailProvider(todoId).notifier).toggleAlert(),
            active: detail.alertEnabled,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: NeonButton(
              label: detail.isDone ? '다시 시작' : '작업 완료',
              icon: detail.isDone ? Icons.replay : Icons.check_circle_outline,
              onTap: () =>
                  ref.read(todoDetailProvider(todoId).notifier).toggleStatus(),
              isPrimary: !detail.isDone,
            ),
          ),
        ],
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

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  /// 시간 추가 — 상세 화면에서 직접 Sheet 호출 → BE PATCH로 즉시 반영.
  void _openAddTimeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TimeConditionEditSheet(
        onSubmit: (tc) =>
            ref.read(todoDetailProvider(todoId).notifier).addTimeCondition(tc),
      ),
    );
  }

  /// 시간 수정 — 기존 항목을 prefill로 Sheet 열기.
  void _openEditTimeSheet(
    BuildContext context,
    WidgetRef ref,
    int index,
    TimeCondition tc,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TimeConditionEditSheet(
        initial: TimeConditionRequest.fromCondition(tc),
        onSubmit: (newTc) => ref
            .read(todoDetailProvider(todoId).notifier)
            .updateTimeCondition(index, newTc),
      ),
    );
  }

  /// 시간 삭제 확인 다이얼로그 → BE PATCH.
  Future<void> _confirmDeleteTime(
    BuildContext context,
    WidgetRef ref,
    int index,
    TimeCondition tc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('시간 조건 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '"${formatTimeCondition(tc)}" 조건을 삭제할까요?',
          style: const TextStyle(color: SpaceColors.white50),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: SpaceColors.white50)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(todoDetailProvider(todoId).notifier)
          .removeTimeCondition(index);
    }
  }

  Future<void> _onEditPlaceTap(
    BuildContext context,
    WidgetRef ref,
    TodoDetail detail,
  ) async {
    final keyword =
        detail.primaryPlace?.name ?? detail.resolvedPlaceLabel ?? '';
    final uri = keyword.isNotEmpty
        ? '/place-search?keyword=${Uri.encodeComponent(keyword)}'
        : '/place-search';

    final result = await context.push<SelectedPlace>(uri);
    if (result == null || !context.mounted) return;

    final notifier = ref.read(todoDetailProvider(todoId).notifier);
    switch (result) {
      case SelectedAliasPlace alias:
        await notifier.setAliasPlace(userPlaceId: alias.userPlaceId);
      case SelectedExternalPlace external:
        await notifier.setExternalPlace(place: external);
      case SelectedGenericKeyword keyword:
        await notifier.setGenericKeyword(keyword: keyword.keyword);
    }
  }

  /// 본문 인라인 편집 시트 — 수정 페이지 진입 없이 content 한 줄만 PATCH.
  Future<void> _openContentEditSheet(
    BuildContext context,
    WidgetRef ref,
    TodoDetail detail,
  ) async {
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContentEditSheet(initialContent: detail.content),
    );
    if (updated == null || !context.mounted) return;
    await ref
        .read(todoDetailProvider(todoId).notifier)
        .updateContent(content: updated);
  }
}

// -- 하위 컴포넌트 --------------------------------------------------

/// 시간 조건 mini-card — type badge + 표현 + 우측 삭제 아이콘.
/// 카드 자체 탭으로 수정 sheet 열림 (옵션 B).
class _TimeConditionCard extends StatelessWidget {
  const _TimeConditionCard({
    required this.condition,
    required this.onTap,
    required this.onDelete,
  });

  final TimeCondition condition;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              // type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel(condition.conditionType),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatTimeCondition(condition),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 연필 IconButton — 카드 탭과 동일 onTap 호출.
              // 카드 InkWell만으론 발견성 낮으니 명시적 affordance를 같이 제공.
              IconButton(
                onPressed: onTap,
                tooltip: '수정',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: onDelete,
                tooltip: '삭제',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent.withOpacity(0.7),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BE enum string → 사용자 친화 한글 라벨 매핑.
  /// formatTimeCondition이 본문 표현을 만들고, 배지는 conditionType 카테고리만 짧게 표시.
  String _typeLabel(String type) {
    switch (type) {
      case 'DATETIME':
        return '일정';
      case 'DATE':
        return '날짜';
      case 'DATE_RANGE':
        return '기간';
      case 'WEEK':
        return '매주';
      case 'TIME_RANGE':
        return '시간대';
      default:
        return type;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: SpaceColors.white50,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.imageUrls,
    required this.initialIndex,
  });
  final List<String> imageUrls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final url = imageUrls[initialIndex];
    return GestureDetector(
      onTap: () => _openFullScreenViewer(context),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SpaceColors.white10),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
    );
  }

  void _openFullScreenViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ImageGalleryViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _ImageGalleryViewer extends StatefulWidget {
  const _ImageGalleryViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) {
              final imageUrl = widget.imageUrls[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 16,
            left: 20,
            child: Text(
              '${_currentIndex + 1} / ${widget.imageUrls.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    required this.active,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active
              ? SpaceColors.neonPurple.withOpacity(0.2)
              : const Color(0xFF2A2A4A),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? SpaceColors.neonPurple : const Color(0x4CA78BFA),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: SpaceColors.neonPurple.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : SpaceColors.white.withOpacity(0.7),
          size: 24,
        ),
      ),
    );
  }
}

/// SPECIFIC/ALIAS의 단일 장소를 미니 지도에 마커로 표시.
/// place.latitude/longitude 둘 다 보장된 상태에서만 호출되는 전제.
///
/// 단일 장소라 마커 탭 정보 띠는 노출하지 않는다 (정보 카드와 중복).
/// 마커 색상은 GENERIC과 동일 규칙: primaryCandidate.activeSlot=true면 활성(초록), 아니면 회색.
class _PrimaryPlaceMap extends StatefulWidget {
  const _PrimaryPlaceMap({required this.place, this.primaryCandidate});

  final TodoPlace place;
  final TodoCandidate? primaryCandidate;

  @override
  State<_PrimaryPlaceMap> createState() => _PrimaryPlaceMapState();
}

class _PrimaryPlaceMapState extends State<_PrimaryPlaceMap> {
  NativeKakaoMapController? _mapController;

  void _applyMarker() {
    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    if (_mapController == null || lat == null || lng == null) return;
    final active = widget.primaryCandidate?.activeSlot ?? false;
    _mapController!.setMarkers([
      CandidateMarker(
        id: widget.place.id.toString(),
        latitude: lat,
        longitude: lng,
        active: active,
        name: widget.place.name,
      ),
    ]);
  }

  @override
  void didUpdateWidget(_PrimaryPlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // primaryCandidate(activeSlot)이 토글되면 마커 색이 즉시 반영되도록 다시 그린다.
    _applyMarker();
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.place.latitude!, widget.place.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: NativeKakaoMap(
          center: center,
          initialLevel: 14,
          onMapCreated: (controller) {
            _mapController = controller;
            _applyMarker();
          },
          onCameraIdle: (_, __) {},
          onCameraMoveStarted: () {},
        ),
      ),
    );
  }
}

/// GENERIC 후보 장소 섹션 — 미니 지도 + 카드 리스트.
///
/// 같은 섹션 안에서 카드 탭 → 지도 panTo 동작이 필요하므로
/// 지도 컨트롤러를 보관할 StatefulWidget으로 분리.
class _CandidateSection extends ConsumerStatefulWidget {
  const _CandidateSection({required this.todoId, required this.candidates});

  final int todoId;
  final List<TodoCandidate> candidates;

  @override
  ConsumerState<_CandidateSection> createState() => _CandidateSectionState();
}

class _CandidateSectionState extends ConsumerState<_CandidateSection> {
  NativeKakaoMapController? _mapController;
  bool _listExpanded = false;
  // 마커 탭 시 정보 표시는 네이티브 KakaoMap 말풍선(badge)이 처리.
  // FE는 더 이상 하단 정보 띠를 그리지 않는다 (정보 중복 회피).

  /// 좌표가 있는 후보만 모아 평균 좌표로 지도 초기 중심을 잡는다.
  /// 후보가 모두 좌표 없음이면 기본값(서울 시청)으로 대체 — UX보다는 안전성 우선.
  LatLng get _initialCenter {
    final withCoord = widget.candidates
        .where((c) => c.place.latitude != null && c.place.longitude != null)
        .toList();
    if (withCoord.isEmpty) return const LatLng(37.5665, 126.9780);
    final lat = withCoord.map((c) => c.place.latitude!).reduce((a, b) => a + b) /
        withCoord.length;
    final lng = withCoord.map((c) => c.place.longitude!).reduce((a, b) => a + b) /
        withCoord.length;
    return LatLng(lat, lng);
  }

  void _applyMarkers() {
    final controller = _mapController;
    if (controller == null) return;
    final markers = widget.candidates
        .where((c) => c.place.latitude != null && c.place.longitude != null)
        .map((c) => CandidateMarker(
              id: c.candidateId.toString(),
              latitude: c.place.latitude!,
              longitude: c.place.longitude!,
              active: c.activeSlot,
              name: c.place.name,
            ))
        .toList();
    controller.setMarkers(markers);
  }

  @override
  void didUpdateWidget(_CandidateSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // toggleAlert/refresh 등으로 후보가 갱신되면 마커도 새로 그린다.
    _applyMarkers();
  }

  void _onCardTap(TodoCandidate c) {
    final lat = c.place.latitude;
    final lng = c.place.longitude;
    if (lat == null || lng == null) return;
    _mapController?.panTo(LatLng(lat, lng));
  }

  /// "특정 장소 지정" — 후보 1개를 골라 SPECIFIC 전환. BE setTodoPlace로 위임.
  /// 다른 후보들은 BE에서 delete 처리되어 후보 풀이 단일 매장으로 정리된다.
  Future<void> _confirmPickSpecific(TodoCandidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('특정 장소 지정', style: TextStyle(color: Colors.white)),
        content: Text(
          '"${candidate.place.name}" 한 곳만 알림 후보로 두고 나머지 후보는 정리됩니다.\n진행할까요?',
          style: const TextStyle(color: SpaceColors.white50, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: SpaceColors.white50)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('지정', style: TextStyle(color: SpaceColors.neonPurple)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final place = candidate.place;
    // setExternalPlace는 SelectedExternalPlace를 받는다. 후보의 TodoPlace에서 변환 — kakaoPlaceId가
    // 후보 등록 시 채워졌으므로 BE saveUserSelectedPlace가 externalPlaceId dedup으로 같은 row 재사용.
    final external = SelectedExternalPlace(
      kakaoPlaceId: place.externalPlaceId,
      placeName: place.name,
      placeLatitude: place.latitude!,
      placeLongitude: place.longitude!,
      addressName: place.address,
      roadAddressName: place.roadAddress,
      phone: place.phone,
      categoryGroupCode: place.categoryGroupCode,
      categoryGroupName: place.categoryGroupName,
      placeUrl: place.placeUrl,
    );
    await ref
        .read(todoDetailProvider(widget.todoId).notifier)
        .setExternalPlace(place: external);
  }

  /// 미리보기에 표시할 카드 개수. 활성(감지중) 후보가 보통 1~2개라는 가정에
  /// 미리보기 3개면 활성 + 대기 후보를 함께 노출 가능.
  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final total = widget.candidates.length;
    final activeCount = widget.candidates.where((c) => c.activeSlot).length;
    // BE에서 활성 우선 → 거리 오름차순으로 정렬해 보내므로 그대로 자른다.
    final visible = _listExpanded || total <= _previewCount
        ? widget.candidates
        : widget.candidates.take(_previewCount).toList();
    final hiddenCount = total - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더 — 총 개수 + 감지중 카운트를 한눈에
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 12),
          child: Row(
            children: [
              const Text(
                '후보 장소',
                style: TextStyle(
                  color: SpaceColors.white50,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              _CandidateBadge(
                label: '감지중 $activeCount',
                color: SpaceColors.success,
              ),
              const SizedBox(width: 6),
              _CandidateBadge(
                label: '총 $total',
                color: SpaceColors.white50,
              ),
            ],
          ),
        ),
        // 미니 지도 — 디버깅 시 위치 가시성이 핵심이라 항상 표시
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: NativeKakaoMap(
              center: _initialCenter,
              onMapCreated: (controller) {
                _mapController = controller;
                _applyMarkers();
              },
              onCameraIdle: (_, __) {},
              onCameraMoveStarted: () {},
              // 마커 탭은 네이티브 KakaoMap이 직접 처리(말풍선 badge 토글)하므로 FE 콜백 불필요.
            ),
          ),
        ),
        // 마커 탭은 네이티브 KakaoMap에서 말풍선(badge)으로 표시되므로 별도 FE 정보 띠 없음.
        // 사용자의 "특정 장소 지정" 액션 진입은 후보 카드의 trailing 버튼.
        const SizedBox(height: 12),
        // 미리보기 카드 (기본 3개)
        ...visible.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CandidateCard(
                candidate: c,
                onTap: () => _onCardTap(c),
                onPickSpecific: () => _confirmPickSpecific(c),
              ),
            )),
        // 더보기/접기 버튼 — 후보가 미리보기보다 많을 때만 노출
        if (total > _previewCount)
          _ShowMoreButton(
            expanded: _listExpanded,
            hiddenCount: hiddenCount,
            onTap: () => setState(() => _listExpanded = !_listExpanded),
          ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? '접기' : '더보기 ($hiddenCount)';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SpaceColors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SpaceColors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: SpaceColors.neonPurple,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: SpaceColors.neonPurple,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.onTap,
    this.onPickSpecific,
  });

  final TodoCandidate candidate;
  final VoidCallback onTap;
  /// non-null이면 우측 [📌] 버튼 노출. GENERIC 후보 카드에서만 SPECIFIC 전환 진입점으로 사용.
  final VoidCallback? onPickSpecific;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final activeColor = c.activeSlot ? SpaceColors.success : SpaceColors.white50;
    final activeLabel = c.activeSlot ? '감지중' : '대기';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SpaceColors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.activeSlot
                ? SpaceColors.success.withOpacity(0.4)
                : SpaceColors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CandidateBadge(label: activeLabel, color: activeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.place.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDistance(c.distanceM),
                  style: const TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 12,
                  ),
                ),
                if (onPickSpecific != null) ...[
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPickSpecific,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SpaceColors.neonPurple.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SpaceColors.neonPurple.withOpacity(0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.push_pin_outlined,
                          color: SpaceColors.neonPurple,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (c.place.roadAddress != null) ...[
              const SizedBox(height: 6),
              Text(
                c.place.roadAddress!,
                style: TextStyle(
                  color: SpaceColors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // monitoringTarget이 false일 때만(=사용자가 명시적으로 제외한 후보) 표시.
            // 일반 케이스에선 줄 자체를 안 그려서 카드 높이 절약.
            if (!c.monitoringTarget) ...[
              const SizedBox(height: 8),
              const Text(
                '모니터링 제외',
                style: TextStyle(
                  color: SpaceColors.neonPink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }
}

class _CandidateBadge extends StatelessWidget {
  const _CandidateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SpacePendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceColors.neonPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: SpaceColors.neonPurple,
            ),
          ),
          SizedBox(width: 14),
          Text(
            'AI가 내용을 분석 중입니다...',
            style: TextStyle(
              color: SpaceColors.neonPurple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 할 일 본문 옆 작은 연필 버튼. 본문 텍스트가 길어도 우측 정렬로 안 가려지게
/// 별도 위젯 분리 + 최소 hit target 36x36 유지.
class _InlineEditButton extends StatelessWidget {
  const _InlineEditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SpaceColors.white10),
        ),
        child: const Icon(
          Icons.edit_outlined,
          color: SpaceColors.white50,
          size: 16,
        ),
      ),
    );
  }
}

/// 할 일 본문 인라인 편집 시트 — 다중 줄 TextField + 저장 버튼.
/// 저장 시 trimmed content를 반환, 취소/빈값/변경 없음이면 null.
/// (변경 없음 판정은 viewmodel.updateContent에서도 한 번 더 한다.)
class _ContentEditSheet extends StatefulWidget {
  const _ContentEditSheet({required this.initialContent});

  final String initialContent;

  @override
  State<_ContentEditSheet> createState() => _ContentEditSheetState();
}

class _ContentEditSheetState extends State<_ContentEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  // BE Todo.content 컬럼 한도와 무관하게 UX 상 본문은 한두 줄짜리 짧은 메모.
  // 너무 길면 카드 목록에서 가독성도 떨어지므로 100자 hard cap.
  static const int _maxLength = 100;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();
    // 시트 열리자마자 키보드 + 끝으로 커서 이동 (편집 즉시 추가/수정 가능)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      Navigator.pop(context); // null로 종료 (viewmodel에서 빈값 가드)
      return;
    }
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: SpaceColors.space900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: SpaceColors.white10)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '할 일 수정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: SpaceTypography.pixelFontFamily,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpaceColors.white10),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLength: _maxLength,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: '할 일 내용을 입력하세요',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  counterStyle: TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 11,
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: SpaceColors.white10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: SpaceColors.white50),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton(label: '저장', onTap: _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 공유 링크 OG 프리뷰 카드.
///
/// 동작:
/// - any_link_preview가 URL을 GET → <head>의 og:* 메타 파싱 (제목/설명/이미지/site)
/// - 카드 자체 탭 → 외부 브라우저로 URL 열림 (패키지 내장 url_launcher)
/// - OG 없음/fetch 실패 → fallback 박스(평문 URL + 링크 아이콘)
///
/// 캐시: any_link_preview 자체가 cache TTL=한 달 메모리 캐시를 가지고 있어 같은
/// URL에 대한 재요청은 즉시 응답. 화면 재진입에도 동일 URL이면 fetch 없이 그대로 그림.
class _SharedLinkCard extends StatelessWidget {
  const _SharedLinkCard({required this.url});

  final String url;

  /// 카드/fallback 박스 탭 핸들러.
  /// - native(iOS/Android): externalApplication → Safari/Chrome 등 사용자 기본 브라우저
  /// - web: platformDefault → window.open(_blank) 새 탭
  /// MissingPluginException은 신규 플러그인 등록 후 dev server 미재시작 시 발생할 수 있어
  /// try/catch로 방어 (실제 운영 빌드에선 안 뜸).
  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[SharedLink] launchUrl failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 잘못된 형식의 URL은 OG fetch 자체가 무의미 → fallback만.
    if (!AnyLinkPreview.isValidLink(url)) {
      return _LinkFallbackBox(url: url);
    }

    // any_link_preview v3에선 onTap을 명시적으로 줘야 카드 탭이 동작한다.
    // 가로 모드는 좁은 폭/긴 도메인에서 내부 Row overflow 이슈가 있어 vertical 사용
    // (Twitter/Slack/Discord 표준 — 이미지 위 + 텍스트 아래).
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AnyLinkPreview(
        link: url,
        onTap: _open,
        displayDirection: UIDirection.uiDirectionVertical,
        backgroundColor: SpaceColors.space900,
        bodyMaxLines: 2,
        bodyTextOverflow: TextOverflow.ellipsis,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        bodyStyle: const TextStyle(
          color: SpaceColors.white50,
          fontSize: 12,
        ),
        borderRadius: 14,
        removeElevation: true,
        boxShadow: const [],
        // 로딩 중 placeholder — 화이트 5% 박스 + 작은 로딩 점
        placeholderWidget: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SpaceColors.white10),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SpaceColors.neonPurple,
              ),
            ),
          ),
        ),
        // OG fetch 실패(메타 없음/타임아웃) — 평문 URL 박스로 fallback.
        // fallback도 InkWell 탭 → _open과 동일하게 외부 브라우저로 열림.
        errorWidget: _LinkFallbackBox(url: url),
        errorImage: '', // 이미지 로드 실패해도 카드는 유지
        errorTitle: url,
        errorBody: '미리보기를 가져올 수 없어요',
      ),
    );
  }
}

/// OG 메타가 없거나 fetch 실패 시 fallback. 단순히 URL을 보여주는 작은 박스.
/// 탭 시 외부 브라우저로 열림 (url_launcher).
class _LinkFallbackBox extends StatelessWidget {
  const _LinkFallbackBox({required this.url});

  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[SharedLink fallback] launchUrl failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SpaceColors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.cyan, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.cyan,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.open_in_new,
              color: SpaceColors.white50,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
