import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_provider.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/cosmic_background.dart';
import '../../../shared/widgets/neon_button.dart';
import '../../../shared/widgets/space_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../model/selected_kakao_place.dart';
import '../model/todo.dart';
import '../model/todo_detail.dart';
import '../util/time_condition_formatter.dart';
import '../viewmodel/todo_detail_viewmodel.dart';
import '../widgets/native_kakao_map.dart';

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
                      color: _todoTypeColor(detail.todoType),
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

                // 4. 할 일 본문 (가장 크게 표시)
                Text(
                  detail.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '등록일: ${_formatDate(detail.createdAt)}',
                  style: const TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 32),

                // 5. 조건 정보 섹션 (장소, 시간)
                _buildInfoSection(context, ref, detail, themeColor),

                const SizedBox(height: 24),

                // 6. 장소 상세 정보 (primaryPlace가 있을 때)
                // 일관성: 후보 섹션과 동일하게 [지도 → 카드] 순서로 배치.
                // GENERIC(=candidates 있음)에선 _CandidateSection이 지도를 그리므로 중복 회피.
                if (detail.primaryPlace != null) ...[
                  if (detail.candidates.isEmpty &&
                      detail.primaryPlace!.latitude != null &&
                      detail.primaryPlace!.longitude != null) ...[
                    _PrimaryPlaceMap(place: detail.primaryPlace!),
                    const SizedBox(height: 12),
                  ],
                  _buildPlaceDetailCard(detail.primaryPlace!, currentGps),
                  const SizedBox(height: 24),
                ],

                // 6-2. GENERIC 후보 장소 (DB에 후보가 있으면 표시)
                if (detail.candidates.isNotEmpty) ...[
                  _CandidateSection(candidates: detail.candidates),
                  const SizedBox(height: 24),
                ],

                // 7. 시각 자료 (첨부 이미지)
                if (detail.imageUrls.isNotEmpty) ...[
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
          // 시간 정보
          Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Colors.cyanAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '실행 시간',
                      style: TextStyle(
                        color: SpaceColors.white50,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    detail.timeConditions.isEmpty
                        ? Text(
                            '시간 조건 없음',
                            style: TextStyle(
                              color: SpaceColors.white.withOpacity(0.7),
                              fontSize: 15,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detail.timeConditions
                                .map(
                                  (tc) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      formatTimeCondition(tc),
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceDetailCard(TodoPlace place, GpsSnapshot? gps) {
    final distanceLabel = _placeDistanceLabel(place, gps);
    return SpaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상세 장소 정보',
            style: TextStyle(
              color: SpaceColors.white50,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            place.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (place.roadAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 14,
                  color: SpaceColors.white50,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.roadAddress!,
                    style: TextStyle(
                      color: SpaceColors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (distanceLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 14,
                  color: SpaceColors.white50,
                ),
                const SizedBox(width: 8),
                Text(
                  distanceLabel,
                  style: TextStyle(
                    color: SpaceColors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 사용자 현재 위치와 장소 좌표 둘 다 있을 때만 "350m" / "1.2km" 라벨을 만든다.
  /// 없으면 null → 호출처에서 줄 자체를 숨김.
  String? _placeDistanceLabel(TodoPlace place, GpsSnapshot? gps) {
    final lat = place.latitude;
    final lng = place.longitude;
    if (lat == null || lng == null || gps == null) return null;
    final meters = Geolocator.distanceBetween(
        gps.latitude, gps.longitude, lat, lng);
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
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


  Color _todoTypeColor(String? type) {
    return switch (type) {
      TodoType.specific => SpaceColors.neonPurple,
      TodoType.generic => Colors.cyanAccent,
      TodoType.alias => SpaceColors.success,
      _ => SpaceColors.white50,
    };
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
    }
  }
}

// -- 하위 컴포넌트 --------------------------------------------------

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
class _PrimaryPlaceMap extends StatefulWidget {
  const _PrimaryPlaceMap({required this.place});

  final TodoPlace place;

  @override
  State<_PrimaryPlaceMap> createState() => _PrimaryPlaceMapState();
}

class _PrimaryPlaceMapState extends State<_PrimaryPlaceMap> {
  NativeKakaoMapController? _mapController;

  void _applyMarker() {
    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    if (_mapController == null || lat == null || lng == null) return;
    _mapController!.setMarkers([
      CandidateMarker(
        id: widget.place.id.toString(),
        latitude: lat,
        longitude: lng,
        active: true, // 단일 장소는 항상 활성으로 강조
      ),
    ]);
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
class _CandidateSection extends StatefulWidget {
  const _CandidateSection({required this.candidates});

  final List<TodoCandidate> candidates;

  @override
  State<_CandidateSection> createState() => _CandidateSectionState();
}

class _CandidateSectionState extends State<_CandidateSection> {
  NativeKakaoMapController? _mapController;
  bool _listExpanded = false;

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
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 미리보기 카드 (기본 3개)
        ...visible.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CandidateCard(candidate: c, onTap: () => _onCardTap(c)),
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

/// 후보 카드 더보기/접기 버튼.
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
  const _CandidateCard({required this.candidate, required this.onTap});

  final TodoCandidate candidate;
  final VoidCallback onTap;

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
