import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permission/permission_health_provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/util/navigation_guard.dart';
import '../../../shared/widgets/my_location_fab.dart';
import '../../todo/model/todo.dart';
import '../../todo/util/todo_type_style.dart';
import '../../todo/widgets/native_kakao_map.dart';
import '../viewmodel/map_viewmodel.dart';

// 기본 카메라 위치 (서울 시청) — GPS 미동의 시 fallback
const _kDefaultLat = 37.5665;
const _kDefaultLng = 126.9780;
const _kBottomNavigationHeight = 90.0;
const _kMapPanelRadius = 20.0;
const _kMapBottomGap = 8.0;
const _kMyLocationFabGap = 14.0;
const _kPeekSheetFabOffset = 236.0;

/// 지도 탭 — 활성 todo 장소들을 카카오 지도에 시각화.
///
/// 표시 정책:
/// - SPECIFIC/ALIAS는 감지중 여부와 무관하게 primary place 좌표를 마커로 표시
/// - GENERIC은 현재 활성 geofence slot에 들어간 후보 좌표만 표시
/// - 같은 좌표 다중 todo는 하나의 마커 + 시트 가로 스크롤로 처리
/// - 감지중 강조는 BE의 geofence_slots.is_active 기준으로 표시
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with NavigationGuardMixin<MapScreen> {
  NativeKakaoMapController? _mapController;
  // 시트에 표시한 카드의 현재 인덱스 (가로 스크롤). 마커 바꿀 때 첫 페이지로 리셋용.
  final PageController _pageController = PageController(viewportFraction: 0.92);
  String? _lastSelectedMarkerId;
  bool _didCenterOnInitialGps = false;
  bool _autoPermissionSheetShown = false;

  bool get _supportsNativeMap =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// 미니 카드 더블 탭으로 같은 상세 화면이 두 번 push되는 것을 방지.
  void _openDetail(int todoId) {
    guardedRunSync(() => context.push('/todos/$todoId'));
  }

  Future<void> _refreshMap() async {
    ref.read(mapProvider.notifier).dismissSelection();
    await ref.read(mapProvider.notifier).load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissionHealth = ref.watch(permissionHealthProvider);
    _showPermissionSheetIfNeeded(permissionHealth);

    // 마커 갱신 — todo/filter가 바뀔 때만 native에 동기한다.
    // selectedMarkerId 변경으로 setMarkers를 다시 호출하면 iOS Poi가 재생성되어
    // 마커 탭 직후 표시 상태가 흔들릴 수 있다.
    ref.listen<MapState>(mapProvider, (prev, next) {
      if (prev?.todos != next.todos ||
          prev?.activeSlots != next.activeSlots ||
          prev?.activeTypeFilters != next.activeTypeFilters) {
        _syncMarkers(next);
      }
      // 사용자 GPS 변화 시 위치 마커 갱신
      if (prev?.currentGps != next.currentGps && next.currentGps != null) {
        _mapController?.setUserLocation(
          LatLng(next.currentGps!.latitude, next.currentGps!.longitude),
        );
        _centerOnGpsIfNeeded(next);
      }
      // 마커 그룹이 바뀌면 시트 첫 페이지로 리셋
      if (prev?.selectedMarkerId != next.selectedMarkerId &&
          next.selectedMarkerId != _lastSelectedMarkerId) {
        _lastSelectedMarkerId = next.selectedMarkerId;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    });

    final state = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: SpaceColors.space950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                _kBottomNavigationHeight + _kMapBottomGap,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChipsBar(
                          activeFilters: state.activeTypeFilters,
                          onToggle: (type) => ref
                              .read(mapProvider.notifier)
                              .toggleTypeFilter(type),
                          visibleCount: state.markerItems.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MapRefreshButton(
                        loading: state.isLoading,
                        onTap: state.isLoading ? null : _refreshMap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _MapPanel(child: _buildMapStack(state))),
                ],
              ),
            ),
          ),
          if (state.isLoading && state.todos.isEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white10,
                color: SpaceColors.neonPurple,
                minHeight: 2,
              ),
            ),

          if (state.error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: _ErrorBanner(
                message: state.error!,
                onRetry: () => ref.read(mapProvider.notifier).load(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapStack(MapState state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildMap(state)),
        if (state.selectedMarkerId != null &&
            state.selectedGroupTodos.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ref.read(mapProvider.notifier).dismissSelection(),
            ),
          ),
        Positioned(
          right: _kMyLocationFabGap,
          bottom: state.selectedMarkerId != null
              ? _kPeekSheetFabOffset
              : _kMyLocationFabGap,
          child: MyLocationFab(gps: state.currentGps, onTap: _panToMyLocation),
        ),
        if (state.selectedMarkerId != null &&
            state.selectedGroupTodos.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MarkerPeekSheet(
              todos: state.selectedGroupTodos,
              pageController: _pageController,
              currentGps: state.currentGps,
              onDismiss: () =>
                  ref.read(mapProvider.notifier).dismissSelection(),
              onCardTap: _openDetail,
            ),
          ),
      ],
    );
  }

  // ── 지도 — iOS/Android 앱은 실제 KakaoMap, 그 외(web/desktop)는 안내 placeholder ─
  Widget _buildMap(MapState state) {
    if (!_supportsNativeMap) {
      return const ColoredBox(
        color: SpaceColors.space800,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                '지도는 모바일 앱에서 확인할 수 있어요',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final center = _initialCenter(state);
    return NativeKakaoMap(
      center: center,
      initialLevel: 15,
      onTap: () => FocusScope.of(context).unfocus(),
      onMapCreated: (controller) {
        _mapController = controller;
        final mapState = ref.read(mapProvider);
        // 첫 마커 sync — viewmodel이 로드 끝나기 전이면 빈 마커, 끝나면 listen에서 호출됨
        _syncMarkers(mapState);
        // 사용자 위치도 첫 sync — 이미 GPS 받았으면 즉시 표시.
        if (mapState.currentGps != null) {
          controller.setUserLocation(
            LatLng(
              mapState.currentGps!.latitude,
              mapState.currentGps!.longitude,
            ),
          );
          _centerOnGpsIfNeeded(mapState);
        }
      },
      onCameraIdle: (_, __) {
        // Phase 1에선 카메라 이벤트로 따로 처리할 게 없음
      },
      onCameraMoveStarted: () {
        // 카메라 이동 시 peek 시트 자동 dismiss — 산업 표준 (Apple/Google Maps)
        final selected = ref.read(mapProvider).selectedMarkerId;
        if (selected != null) {
          ref.read(mapProvider.notifier).dismissSelection();
        }
      },
      onMarkerTap: (id) {
        ref.read(mapProvider.notifier).selectMarker(id);
      },
    );
  }

  LatLng _initialCenter(MapState state) {
    final gps = state.currentGps;
    if (gps != null) return LatLng(gps.latitude, gps.longitude);
    return const LatLng(_kDefaultLat, _kDefaultLng);
  }

  /// viewmodel의 markerGroups를 native KakaoMap에 동기.
  /// 마커 active 표시는 그룹 내 todo 중 하나라도 alertEnabled=true면 true (감지중 proxy).
  /// 그룹 다중 여부와 관계없이 마커 위 숫자 배지에 등록된 할 일 개수를 표시한다.
  void _syncMarkers(MapState state) {
    final controller = _mapController;
    if (controller == null) return;

    final markers = <CandidateMarker>[];
    state.markerGroups.forEach((id, group) {
      final first = group.first;
      final lat = first.latitude;
      final lng = first.longitude;
      // 진짜 감지중 = 그룹 중 하나라도 BE의 activeSlot=true
      final active = group.any((item) => item.active);
      // 같은 좌표 다중 todo 그룹은 첫 항목의 todoType을 대표색으로 사용.
      // 실제론 같은 매장이라 같은 타입일 확률 높고, 다중 타입 케이스는 시트 카드로 분리됨.
      markers.add(
        CandidateMarker(
          id: id,
          latitude: lat,
          longitude: lng,
          active: active,
          placeType: first.todo.todoType,
          badgeText: group.length > 1 ? group.length.toString() : null,
        ),
      );
    });
    controller.setMarkers(markers);
  }

  void _centerOnGpsIfNeeded(MapState state) {
    if (_didCenterOnInitialGps) return;
    final controller = _mapController;
    if (controller == null) return;
    final gps = state.currentGps;
    if (gps == null) return;
    _didCenterOnInitialGps = true;
    controller.panTo(LatLng(gps.latitude, gps.longitude));
  }

  void _panToMyLocation() {
    final gps = ref.read(mapProvider).currentGps;
    if (gps == null) {
      MyLocationFab.showLocationUnavailableSheet(context);
      return;
    }
    _mapController?.panTo(LatLng(gps.latitude, gps.longitude));
  }

  void _showPermissionSheetIfNeeded(
    AsyncValue<PermissionHealth> permissionHealth,
  ) {
    final health = permissionHealth.valueOrNull;
    if (health == null || !health.hasWarning || _autoPermissionSheetShown) {
      return;
    }
    _autoPermissionSheetShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MyLocationFab.showLocationUnavailableSheet(context);
    });
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kMapPanelRadius),
          child: child,
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kMapPanelRadius),
              border: Border.all(color: SpaceColors.white10),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapRefreshButton extends StatelessWidget {
  const _MapRefreshButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: '새로고침',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SpaceColors.space900.withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: enabled ? SpaceColors.white20 : SpaceColors.white10,
              ),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SpaceColors.neonPurple,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: enabled
                          ? SpaceColors.neonPurple
                          : SpaceColors.white20,
                      size: 19,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 상단 필터 칩 ──────────────────────────────────────────────────────
/// 장소 타입별 필터 칩 (가로 스크롤).
/// activeFilters가 비어있으면 [전체] 칩이 강조되고, 특정 타입을 누르면 그 타입만 표시.
/// 한 타입을 다시 누르면 해제 → empty가 되면 전체 표시로 복귀.
class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({
    required this.activeFilters,
    required this.onToggle,
    required this.visibleCount,
  });

  final Set<String> activeFilters;
  final ValueChanged<String> onToggle;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _ChipData(
        type: null,
        label: '전체',
        color: SpaceColors.white50,
        count: visibleCount,
      ),
      _ChipData(
        type: TodoType.specific,
        label: '특정',
        color: todoTypeColor(TodoType.specific),
        count: null,
      ),
      _ChipData(
        type: TodoType.alias,
        label: '내장소',
        color: todoTypeColor(TodoType.alias),
        count: null,
      ),
      _ChipData(
        type: TodoType.generic,
        label: '포괄',
        color: todoTypeColor(TodoType.generic),
        count: null,
      ),
    ];

    // SingleChildScrollView + Row로 자식 자연 측정 — 고정 SizedBox로 묶으면
    // web/native 폰트 메트릭(특히 line-height) 차이로 1~2px overflow가 발생.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _TypeChip(
              data: chips[i],
              selected: chips[i].type == null
                  ? activeFilters.isEmpty
                  : activeFilters.contains(chips[i].type),
              onTap: () {
                final t = chips[i].type;
                if (t == null) {
                  // "전체" → 모든 필터 해제 (이미 비어있으면 noop)
                  if (activeFilters.isNotEmpty) {
                    for (final f in {...activeFilters}) {
                      onToggle(f);
                    }
                  }
                } else {
                  onToggle(t);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipData {
  const _ChipData({
    required this.type,
    required this.label,
    required this.color,
    required this.count,
  });
  final String? type;
  final String label;
  final Color color;
  final int? count;
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _ChipData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? data.color.withOpacity(0.18)
                : SpaceColors.space900.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? data.color.withOpacity(0.6)
                  : SpaceColors.white10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.label,
                style: TextStyle(
                  color: selected ? Colors.white : SpaceColors.white50,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (data.count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '${data.count}',
                  style: TextStyle(
                    color: selected ? data.color : SpaceColors.white50,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── peek 바텀 시트 ────────────────────────────────────────────────────
/// 마커 탭 시 화면 하단에서 슬라이드업.
/// 다중 todo는 가로 스크롤 (PageView) + 하단 dots.
class _MarkerPeekSheet extends StatelessWidget {
  const _MarkerPeekSheet({
    required this.todos,
    required this.pageController,
    required this.currentGps,
    required this.onDismiss,
    required this.onCardTap,
  });

  final List<MapTodoMarker> todos;
  final PageController pageController;
  final Object? currentGps; // GpsSnapshot? — distance 계산용
  final VoidCallback onDismiss;
  final ValueChanged<int> onCardTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 시트 영역 외부 탭은 Stack 다른 레이어가 처리. 시트 안 영역은 propagation 차단.
      onTap: () {},
      child: Container(
        decoration: const BoxDecoration(
          color: SpaceColors.space900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: SpaceColors.white10),
            left: BorderSide(color: SpaceColors.white10),
            right: BorderSide(color: SpaceColors.white10),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 + 닫기
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    color: SpaceColors.white50,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 4),

            // 카드 (단일이면 1장, 다중이면 가로 스크롤)
            SizedBox(
              height: 152,
              child: PageView.builder(
                controller: pageController,
                itemCount: todos.length,
                physics: todos.length > 1
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) {
                  final marker = todos[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _TodoMiniCard(
                      marker: marker,
                      onTap: () => onCardTap(marker.todo.id),
                    ),
                  );
                },
              ),
            ),

            // dots (다중일 때만)
            if (todos.length > 1) ...[
              const SizedBox(height: 10),
              _PageDots(count: todos.length, pageController: pageController),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodoMiniCard extends StatelessWidget {
  const _TodoMiniCard({required this.marker, required this.onTap});

  final MapTodoMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final todo = marker.todo;
    final typeColor = todoTypeColor(todo.todoType);
    final category = todo.category;
    final categoryLabel = category != null
        ? TodoCategory.labels[category]
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceColors.space800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpaceColors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 배지 row — 카테고리 + 타입 점 + 감지중
          Row(
            children: [
              if (categoryLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: SpaceColors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              // 장소 타입 점 (색만으로 분류)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              // 정확한 감지중 = BE의 geofence_slots.is_active=true.
              if (marker.active) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SpaceColors.neonCyan.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: SpaceColors.neonCyan.withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    '감지중',
                    style: TextStyle(
                      color: SpaceColors.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // 2. 본문
          Text(
            todo.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              if (todo.resolvedPlaceLabel != null)
                Expanded(
                  child: Text(
                    todo.resolvedPlaceLabel!,
                    style: const TextStyle(
                      color: SpaceColors.white50,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '상세보기',
                  style: TextStyle(
                    color: SpaceColors.neonPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatefulWidget {
  const _PageDots({required this.count, required this.pageController});

  final int count;
  final PageController pageController;

  @override
  State<_PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<_PageDots> {
  int _current = 0;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final page = widget.pageController.page;
    if (page == null) return;
    final next = page.round();
    if (next != _current) {
      setState(() => _current = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final selected = i == _current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? SpaceColors.neonPurple : SpaceColors.white20,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── 에러 배너 ─────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SpaceColors.space900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SpaceColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '지도 데이터를 불러오지 못했어요',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: SpaceTypography.pixelFontFamily,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시',
              style: TextStyle(color: SpaceColors.neonPurple, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
