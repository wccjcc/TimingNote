import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../../todo/model/todo.dart';
import '../../todo/util/todo_type_style.dart';
import '../../todo/widgets/native_kakao_map.dart';
import '../viewmodel/map_viewmodel.dart';

// 기본 카메라 위치 (서울 시청) — GPS 미동의 시 fallback
const _kDefaultLat = 37.5665;
const _kDefaultLng = 126.9780;

/// 지도 탭 — 활성 todo 장소들을 카카오 지도에 시각화.
///
/// Phase 1 정책:
/// - 모든 active todo의 primary place 좌표를 마커로 표시 (SPECIFIC/ALIAS/GENERIC 무관)
///   · Phase 2에서 BE API에 activeSlot 확장 후 GENERIC은 감지중만 필터링
/// - 같은 좌표 다중 todo는 하나의 마커 + 시트 가로 스크롤로 처리
/// - 감지중 강조는 alertEnabled를 proxy로 사용 (BE의 정확한 activeSlot은 Phase 2)
/// - 마커 색 분기는 Swift 확장 필요 — Phase 2에서 도입. 현재는 시트 카드 색으로 타입 시각화.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NativeKakaoMapController? _mapController;
  // 시트에 표시한 카드의 현재 인덱스 (가로 스크롤). 마커 바꿀 때 첫 페이지로 리셋용.
  final PageController _pageController = PageController(viewportFraction: 0.92);
  String? _lastSelectedMarkerId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 마커 갱신 — 상태 변화 시 native에 동기. selectMarker로 시트만 바뀔 때도 호출되지만
    // setMarkers는 idempotent라서 자주 호출해도 비용 작음.
    ref.listen<MapState>(mapProvider, (prev, next) {
      if (prev?.todos != next.todos ||
          prev?.activeTypeFilters != next.activeTypeFilters ||
          prev?.selectedMarkerId != next.selectedMarkerId) {
        _syncMarkers(next);
      }
      // 사용자 GPS 변화 시 위치 마커 갱신
      if (prev?.currentGps != next.currentGps && next.currentGps != null) {
        _mapController?.setUserLocation(
          LatLng(next.currentGps!.latitude, next.currentGps!.longitude),
        );
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
      // StackFit.expand로 Stack이 풀스크린 차지. fit이 loose면 non-positioned 자식
      // (SafeArea+칩)의 작은 크기에 Stack이 묶여 Positioned(bottom:24)가 칩 바로 아래로
      // 떠버리는 버그가 발생함. (Web에서 더 명확히 노출됨)
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. 카카오 지도 (전체 화면) ─────────────────────────────
          Positioned.fill(
            child: _buildMap(state),
          ),

          // ── 2. 상단 필터 칩 + 안전 영역 ────────────────────────────
          // Positioned로 감싸서 Stack의 크기 결정에 미관여하게 함 — Stack은
          // expand로 풀스크린 유지, 칩은 위에만 떠있는 layer.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _FilterChipsBar(
                  activeFilters: state.activeTypeFilters,
                  onToggle: (type) =>
                      ref.read(mapProvider.notifier).toggleTypeFilter(type),
                  totalCount: state.todos.length,
                  visibleCount: state.filteredTodos.length,
                ),
              ),
            ),
          ),

          // ── 3. 우하단 FAB "내 위치로" ──────────────────────────────
          Positioned(
            right: 16,
            bottom: state.selectedMarkerId != null ? 220 : 24,
            child: _MyLocationFab(
              gps: state.currentGps,
              onTap: _panToMyLocation,
            ),
          ),

          // ── 4. peek 바텀 시트 ──────────────────────────────────────
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
                onCardTap: (todoId) => context.push('/todos/$todoId'),
              ),
            ),

          // ── 5. 로딩 인디케이터 (초기 진입) ─────────────────────────
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

          // ── 6. 에러 배너 ───────────────────────────────────────────
          if (state.error != null)
            Positioned(
              top: 80,
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

  // ── 지도 — iOS만 실제 KakaoMap, 그 외(web/android)는 안내 placeholder ─
  Widget _buildMap(MapState state) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      // 둥근 카드 + 외곽 마진. 상단 칩과 시각적으로 분리되도록 top 마진을 칩 영역(약 60px)
      // 보다 크게 잡아 칩 아래에서 시작하는 듯한 인상.
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 64, 16, 16),
          decoration: BoxDecoration(
            color: SpaceColors.space800,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SpaceColors.white10),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, color: Colors.white24, size: 64),
                SizedBox(height: 16),
                Text(
                  '지도는 iOS 앱에서 확인할 수 있어요',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = _initialCenter(state);
    return NativeKakaoMap(
      center: center,
      initialLevel: 15,
      onMapCreated: (controller) {
        _mapController = controller;
        final mapState = ref.read(mapProvider);
        // 첫 마커 sync — viewmodel이 로드 끝나기 전이면 빈 마커, 끝나면 listen에서 호출됨
        _syncMarkers(mapState);
        // 사용자 위치도 첫 sync — 이미 GPS 받았으면 즉시 표시.
        if (mapState.currentGps != null) {
          controller.setUserLocation(
            LatLng(mapState.currentGps!.latitude, mapState.currentGps!.longitude),
          );
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
        _panToMarker(id);
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
  /// 그룹 다중일 때 name에 "장소명 (N)" 형태로 개수 노출.
  void _syncMarkers(MapState state) {
    final controller = _mapController;
    if (controller == null) return;

    final markers = <CandidateMarker>[];
    state.markerGroups.forEach((id, group) {
      final first = group.first;
      final lat = first.placeLatitude!;
      final lng = first.placeLongitude!;
      // 진짜 감지중 = 그룹 중 하나라도 BE의 activeSlot=true
      final active = group.any((t) => t.activeSlot);
      final label = first.resolvedPlaceLabel ?? '장소';
      final name = group.length > 1 ? '$label (${group.length})' : label;
      // 같은 좌표 다중 todo 그룹은 첫 항목의 todoType을 대표색으로 사용.
      // 실제론 같은 매장이라 같은 타입일 확률 높고, 다중 타입 케이스는 시트 카드로 분리됨.
      markers.add(CandidateMarker(
        id: id,
        latitude: lat,
        longitude: lng,
        active: active,
        name: name,
        placeType: first.todoType,
      ));
    });
    controller.setMarkers(markers);
  }

  void _panToMarker(String markerId) {
    final controller = _mapController;
    if (controller == null) return;
    final group = ref.read(mapProvider).markerGroups[markerId];
    if (group == null || group.isEmpty) return;
    final first = group.first;
    if (!first.hasPlaceCoords) return;
    controller.panTo(LatLng(first.placeLatitude!, first.placeLongitude!));
  }

  void _panToMyLocation() {
    final gps = ref.read(mapProvider).currentGps;
    if (gps == null) {
      // GPS 권한 거부/실패 시 안내 — 간단히 toast 정도. Phase 1에선 silently 무시.
      return;
    }
    _mapController?.panTo(LatLng(gps.latitude, gps.longitude));
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
    required this.totalCount,
    required this.visibleCount,
  });

  final Set<String> activeFilters;
  final ValueChanged<String> onToggle;
  final int totalCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _ChipData(
        type: null,
        label: '전체',
        color: SpaceColors.white50,
        count: totalCount,
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
                    color: selected
                        ? data.color
                        : SpaceColors.white50,
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

// ── 내 위치 FAB ───────────────────────────────────────────────────────
class _MyLocationFab extends StatelessWidget {
  const _MyLocationFab({required this.gps, required this.onTap});

  // gps가 null이면 권한 없음/실패 → 버튼은 노출하되 회색 + 비활성.
  final Object? gps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = gps != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: SpaceColors.space900,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? SpaceColors.neonPurple.withOpacity(0.6)
                  : SpaceColors.white10,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: SpaceColors.neonPurple.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.my_location,
            color: enabled ? SpaceColors.neonPurple : SpaceColors.white20,
            size: 20,
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

  final List<TodoItem> todos;
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
              height: 140,
              child: PageView.builder(
                controller: pageController,
                itemCount: todos.length,
                physics: todos.length > 1
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) {
                  final todo = todos[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _TodoMiniCard(
                      todo: todo,
                      onTap: () => onCardTap(todo.id),
                    ),
                  );
                },
              ),
            ),

            // dots (다중일 때만)
            if (todos.length > 1) ...[
              const SizedBox(height: 10),
              _PageDots(
                count: todos.length,
                pageController: pageController,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodoMiniCard extends StatelessWidget {
  const _TodoMiniCard({required this.todo, required this.onTap});

  final TodoItem todo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = todoTypeColor(todo.todoType);
    final category = todo.category;
    final categoryLabel = category != null ? TodoCategory.labels[category] : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  // 정확한 감지중 = BE의 geofence_slots.is_active=true (activeSlot).
                  // alertEnabled는 사용자 의도, activeSlot은 실제 슬롯 등록 여부 — 후자가 진실.
                  if (todo.activeSlot) ...[
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
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: SpaceColors.white50,
                    size: 18,
                  ),
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
              // 3. 장소 라벨
              if (todo.resolvedPlaceLabel != null)
                Text(
                  todo.resolvedPlaceLabel!,
                  style: const TextStyle(
                    color: SpaceColors.white50,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
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
            color: selected
                ? SpaceColors.neonPurple
                : SpaceColors.white20,
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
