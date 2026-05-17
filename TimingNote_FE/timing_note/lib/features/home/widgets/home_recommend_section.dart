import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/colors.dart';
import '../model/home_recommendation.dart';
import '../../todo/model/todo.dart';

String _formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}

class HomeRecommendSection extends StatefulWidget {
  const HomeRecommendSection({
    super.key,
    required this.currentLocationLabel,
    required this.items,
    required this.isLoading,
    required this.onCompleteTodo,
    required this.onRefresh,
    this.currentLatitude,
    this.currentLongitude,
    this.errorMessage,
  });

  final String currentLocationLabel;
  final List<HomeRecommendationItem> items;
  final bool isLoading;
  final String? errorMessage;
  final double? currentLatitude;
  final double? currentLongitude;
  final Future<void> Function(int todoId) onCompleteTodo;
  final Future<void> Function() onRefresh;

  @override
  State<HomeRecommendSection> createState() => _HomeRecommendSectionState();
}

class _HomeRecommendSectionState extends State<HomeRecommendSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _activeGroupId;
  final Set<int> _removingIds = <int>{};
  static const double _currentLat = 35.1530;
  static const double _currentLng = 126.8526;
  List<HomeRecommendationItem> _items = <HomeRecommendationItem>[];
  List<HomeRecommendationItem> _nodeItems = <HomeRecommendationItem>[];
  Map<int, _NodeLayoutData> _nodeLayouts = <int, _NodeLayoutData>{};
  String _layoutSignature = '';

  @override
  void initState() {
    super.initState();
    _items = List<HomeRecommendationItem>.from(widget.items);
    _ensureNodeLayouts();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat();
  }

  @override
  void didUpdateWidget(covariant HomeRecommendSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.currentLatitude != widget.currentLatitude ||
        oldWidget.currentLongitude != widget.currentLongitude;
    if (oldWidget.items != widget.items) {
      if (_removingIds.isNotEmpty) return;
      _items = List<HomeRecommendationItem>.from(widget.items);
      _ensureNodeLayouts(force: true);
      if (_activeGroupId != null &&
          !_items.any((e) => e.groupId == _activeGroupId)) {
        _activeGroupId = null;
      }
    } else if (locationChanged) {
      _ensureNodeLayouts(force: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapNode(int groupId) {
    setState(
      () => _activeGroupId = _activeGroupId == groupId ? null : groupId,
    );
  }

  Future<void> _onTapCompleteItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (_removingIds.contains(item.todoId)) return;

    setState(() {
      _removingIds.add(item.todoId);
      if (!_items.any((e) => e.groupId == item.groupId && e.todoId != item.todoId)) {
        _activeGroupId = null;
      }
    });

    try {
      await widget.onCompleteTodo(item.todoId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _removingIds.remove(item.todoId);
      });
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.todoId == item.todoId);
        _removingIds.remove(item.todoId);
        _ensureNodeLayouts(force: true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        _ensureNodeLayouts();
        final nodeItems = _nodeItems;
        final nodeLayouts = _nodeLayouts;
        final isInitialLoading = widget.isLoading && _items.isEmpty;
        final hasError =
            widget.errorMessage != null && widget.errorMessage!.trim().isNotEmpty;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: SpaceColors.neonPurple,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    if (isInitialLoading)
                      _LocationSkeleton(progress: progress)
                    else
                      Text(
                        widget.currentLocationLabel,
                        style: TextStyle(
                          color: SpaceColors.neonPurple.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        onPressed: widget.isLoading ? null : widget.onRefresh,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: SpaceColors.neonPurple,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: Center(
                  child: SizedBox(
                    width: 320,
                    height: 320,
                    child: Stack(
                      children: [
                        const Positioned(
                          left: 88,
                          top: 88,
                          child: _OrbitRing(radius: 72),
                        ),
                        const Positioned(
                          left: 52,
                          top: 52,
                          child: _OrbitRing(radius: 108),
                        ),
                        const Positioned(
                          left: 22,
                          top: 22,
                          child: _OrbitRing(radius: 138),
                        ),
                        Positioned(
                          left: 22,
                          top: 22,
                          child: _RadarSweep(progress: progress, radius: 138),
                        ),
                        Positioned(
                          left: 117,
                          top: 117,
                          child: _CenterPlanet(
                            progress: progress,
                            isError: hasError,
                            isLoading: isInitialLoading,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: _activeGroupId == null,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => setState(() => _activeGroupId = null),
                            ),
                          ),
                        ),
                        if (!isInitialLoading) ...[
                          ...List.generate(nodeItems.length, (i) {
                            final item = nodeItems[i];
                            if (_activeGroupId == item.groupId) {
                              return const SizedBox.shrink();
                            }
                            final layout = nodeLayouts[item.groupId];
                            return _NodeStub(
                              key: ValueKey('node-${item.groupId}'),
                              isRemoving: _removingIds.contains(item.todoId) &&
                                  item.todoCount <= 1,
                              isActive: false,
                              angle: layout?.angle ?? 0,
                              radius: layout?.radius ?? 72,
                              centerX: 160,
                              centerY: 160,
                              color: _CategoryPalette.colorForCategory(item.category),
                              image:
                                  'assets/images/paw_node_${_CategoryPalette.hexForCategory(item.category)}.png',
                              placeLabel: item.place,
                              distanceLabel: _formatDistance(item.distanceMeters),
                              badgeCount: item.todoCount,
                              floatPhase: (progress * math.pi * 2) + (i * 0.9),
                              onTap: () => _onTapNode(item.groupId),
                            );
                          }),
                          if (_activeGroupId != null &&
                              nodeItems.any((e) => e.groupId == _activeGroupId))
                            (() {
                              final i = nodeItems.indexWhere(
                                (e) => e.groupId == _activeGroupId,
                              );
                              final item = nodeItems[i];
                              final layout = nodeLayouts[item.groupId];
                              return _NodeStub(
                                key: ValueKey('active-node-${item.groupId}'),
                                isRemoving: _removingIds.contains(item.todoId) &&
                                    item.todoCount <= 1,
                                isActive: true,
                                angle: layout?.angle ?? 0,
                                radius: layout?.radius ?? 72,
                                centerX: 160,
                                centerY: 160,
                                color: _CategoryPalette.colorForCategory(item.category),
                                image:
                                    'assets/images/paw_node_${_CategoryPalette.hexForCategory(item.category)}.png',
                                placeLabel: item.place,
                                distanceLabel: _formatDistance(item.distanceMeters),
                                badgeCount: item.todoCount,
                                floatPhase: (progress * math.pi * 2) + (i * 0.9),
                                onTap: () => _onTapNode(item.groupId),
                              );
                            })(),
                        ],
                        if (_items.isEmpty && !isInitialLoading) const _EmptyHint(),
                        if (isInitialLoading)
                          const _LoadingHint(text: '추천 할일 생각중이다냥..'),
                        if (hasError)
                          const _LoadingHint(
                            text: '추천에 실패했다냥..',
                            borderColor: SpaceColors.error,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isInitialLoading &&
                  _activeGroupId != null &&
                  _items.any((e) => e.groupId == _activeGroupId))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _ActivePlaceInfo(
                    place: _items.firstWhere((e) => e.groupId == _activeGroupId).place,
                    distance: _formatDistance(
                      _items.firstWhere((e) => e.groupId == _activeGroupId).distanceMeters,
                    ),
                    color: _CategoryPalette.colorForCategory(
                      _items.firstWhere((e) => e.groupId == _activeGroupId).category,
                    ),
                  ),
                ),
              if (!isInitialLoading) Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    return _CardStub(
                      key: ValueKey('card-${item.groupId}-${item.todoId}-$i'),
                      item: item,
                      isActive: _activeGroupId == item.groupId,
                      isRemoving: _removingIds.contains(item.todoId),
                      onDone: () {
                        _onTapCompleteItem(i);
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _ensureNodeLayouts({bool force = false}) {
    final lat = widget.currentLatitude ?? _currentLat;
    final lng = widget.currentLongitude ?? _currentLng;
    final signature = [
      lat.toStringAsFixed(6),
      lng.toStringAsFixed(6),
      ..._items.map((e) => '${e.groupId}:${e.distanceMeters}:${e.placeLat}:${e.placeLng}'),
    ].join('|');
    if (!force && signature == _layoutSignature) return;

    _layoutSignature = signature;
    _nodeItems = <HomeRecommendationItem>[
      ...{
        for (final item in _items) item.groupId: item,
      }.values,
    ];

    final maxDistance = _nodeItems.isEmpty
        ? 1.0
        : _nodeItems
            .map((e) => e.distanceMeters)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

    final nodeLayouts = <int, _NodeLayoutData>{};
    final placedOffsets = <Offset>[];
    for (var i = 0; i < _nodeItems.length; i++) {
      final item = _nodeItems[i];
      final bearingDeg = _calculateBearingDegrees(
        fromLat: lat,
        fromLng: lng,
        toLat: item.placeLat,
        toLng: item.placeLng,
      );
      final baseAngle = (bearingDeg * math.pi / 180) - (math.pi / 2);
      final t = (item.distanceMeters / maxDistance).clamp(0.0, 1.0);
      final normalized = 0.28 + (0.72 * t);
      final baseRadius = 72 + ((138 - 72) * normalized);

      var adjustedAngle = baseAngle;
      var adjustedRadius = baseRadius;
      for (var attempt = 0; attempt < 12; attempt++) {
        final dx = math.cos(adjustedAngle) * adjustedRadius;
        final dy = math.sin(adjustedAngle) * adjustedRadius;
        final current = Offset(dx, dy);
        final isOverlapped = placedOffsets.any(
          (prev) => (prev - current).distance < 34,
        );
        if (!isOverlapped) {
          placedOffsets.add(current);
          break;
        }
        final step = 0.12 * ((attempt ~/ 2) + 1);
        adjustedAngle = baseAngle + (attempt.isEven ? step : -step);
        adjustedRadius = (baseRadius + (attempt.isEven ? 6 : -6)).clamp(
          70.0,
          146.0,
        );
        if (attempt == 11) {
          placedOffsets.add(current);
        }
      }
      nodeLayouts[item.groupId] = _NodeLayoutData(
        angle: adjustedAngle,
        radius: adjustedRadius,
      );
    }
    _nodeLayouts = nodeLayouts;
  }

  String _bearingToText(double bearingDeg) {
    final d = (bearingDeg % 360 + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'N';
    if (d < 67.5) return 'NE';
    if (d < 112.5) return 'E';
    if (d < 157.5) return 'SE';
    if (d < 202.5) return 'S';
    if (d < 247.5) return 'SW';
    if (d < 292.5) return 'W';
    return 'NW';
  }

  double _calculateBearingDegrees({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final fromLatRad = fromLat * math.pi / 180;
    final toLatRad = toLat * math.pi / 180;
    final dLngRad = (toLng - fromLng) * math.pi / 180;
    final y = math.sin(dLngRad) * math.cos(toLatRad);
    final x = math.cos(fromLatRad) * math.sin(toLatRad) -
        math.sin(fromLatRad) * math.cos(toLatRad) * math.cos(dLngRad);
    final theta = math.atan2(y, x) * 180 / math.pi;
    return (theta + 360) % 360;
  }
}

class _CenterPlanet extends StatelessWidget {
  const _CenterPlanet({
    required this.progress,
    this.isError = false,
    this.isLoading = false,
  });
  final double progress;
  final bool isError;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    final floatY = math.sin(progress * math.pi * 2) * 5.5;
    return Transform.translate(
      offset: Offset(0, floatY),
      child: SizedBox(
        width: 86,
        height: 86,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SpaceColors.neonPurple.withValues(alpha: 0.16),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SpaceColors.neonViolet.withValues(alpha: 0.14),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            ClipOval(
              child: Image.asset(
                isError
                    ? 'assets/images/nyang_star_error.png'
                    : (isLoading
                        ? 'assets/images/nyang_star_loading.png'
                        : 'assets/images/nyang_star_1.png'),
                width: 86,
                height: 86,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeStub extends StatefulWidget {
  const _NodeStub({
    super.key,
    required this.isRemoving,
    required this.isActive,
    required this.angle,
    required this.radius,
    required this.centerX,
    required this.centerY,
    required this.color,
    required this.image,
    required this.placeLabel,
    required this.distanceLabel,
    required this.badgeCount,
    required this.floatPhase,
    required this.onTap,
  });
  final bool isRemoving;
  final bool isActive;
  final double angle;
  final double radius;
  final double centerX;
  final double centerY;
  final Color color;
  final String image;
  final String placeLabel;
  final String distanceLabel;
  final int badgeCount;
  final double floatPhase;
  final VoidCallback onTap;

  @override
  State<_NodeStub> createState() => _NodeStubState();
}

class _NodeStubState extends State<_NodeStub> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dx = math.cos(widget.angle) * widget.radius;
    final dy = math.sin(widget.angle) * widget.radius;
    final floatY = math.sin(widget.floatPhase) * 4.0;
    return Positioned(
      left: widget.centerX + dx - 36,
      top: widget.centerY + dy - 24 + floatY,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.isRemoving ? 0 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: _pressed ? 0.88 : 1.0,
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(
                            alpha: widget.isActive ? 0.52 : 0.34,
                          ),
                          blurRadius: widget.isActive ? 18 : 12,
                          spreadRadius: widget.isActive ? 2 : 1,
                        ),
                      ],
                    ),
                    child: ClipOval(child: Image.asset(widget.image, fit: BoxFit.cover)),
                  ),
                  if (widget.badgeCount > 1)
                    Transform.translate(
                      offset: const Offset(16, -42),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: SpaceColors.neonPink,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.86),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${widget.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Galmuri11',
                          ),
                        ),
                      ),
                    ),
                  if (widget.isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SpaceColors.space900.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.color.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        widget.placeLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontFamily: 'Galmuri11',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardStub extends StatelessWidget {
  const _CardStub({
    super.key,
    required this.item,
    required this.isActive,
    required this.isRemoving,
    required this.onDone,
  });
  final HomeRecommendationItem item;
  final bool isActive;
  final bool isRemoving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _CategoryPalette.colorForCategory(item.category);
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      offset: isRemoving ? const Offset(1, 0) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isRemoving ? 0 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: isActive
                ? categoryColor.withValues(alpha: 0.20)
                : SpaceColors.space800.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? categoryColor.withValues(alpha: 0.9)
                  : categoryColor.withValues(alpha: 0.35),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: isActive ? 0.30 : 0.20),
                blurRadius: isActive ? 22 : 18,
                spreadRadius: isActive ? 2 : 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        _CategoryPalette.labelForCategory(item.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Galmuri11',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 14, color: SpaceColors.neonPurple),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.place} (${_formatDistance(item.distanceMeters)})',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: isRemoving ? null : onDone,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(76, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      foregroundColor: Colors.white,
                      backgroundColor: SpaceColors.neonPurple.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: SpaceColors.neonPurple.withValues(alpha: 0.78),
                        ),
                      ),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('완료'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 196,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE61A1A2E),
            border: Border.all(color: const Color(0xFFA78BFA), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '할일이 없다냥..',
            style: TextStyle(fontFamily: 'Galmuri11', fontSize: 11, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ActivePlaceInfo extends StatelessWidget {
  const _ActivePlaceInfo({
    required this.place,
    required this.distance,
    required this.color,
  });

  final String place;
  final String distance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SpaceColors.space900.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        '$place ($distance)',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Galmuri11',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrbitRing extends StatelessWidget {
  const _OrbitRing({required this.radius});
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SpaceColors.neonPurple.withValues(alpha: 0.20), width: 1),
        ),
      );
}

class _RadarSweep extends StatelessWidget {
  const _RadarSweep({required this.progress, required this.radius});
  final double progress;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi * 2;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          _buildSweepLine(angle, 1.0, 0),
          _buildSweepLine(angle, 0.42, -0.09),
          _buildSweepLine(angle, 0.22, -0.18),
        ],
      ),
    );
  }

  Widget _buildSweepLine(double baseAngle, double opacityFactor, double deltaAngle) {
    return Positioned(
      left: radius,
      top: radius - 1,
      child: Transform.rotate(
        angle: baseAngle + deltaAngle,
        alignment: Alignment.centerLeft,
        child: Container(
          width: radius,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                SpaceColors.neonPurple.withValues(alpha: 0.0),
                SpaceColors.neonPurple.withValues(alpha: 0.09 * opacityFactor),
                SpaceColors.neonPurple.withValues(alpha: 0.30 * opacityFactor),
              ],
              stops: const [0.0, 0.68, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceColors.neonPurple.withValues(alpha: 0.42 * opacityFactor),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPalette {
  static const Color acquireColor = SpaceColors.neonPurple; // #A78BFA
  static const Color socialColor = SpaceColors.neonPink; // #F472B6
  static const Color healthColor = SpaceColors.neonViolet; // #8B5CF6
  static const Color maintenanceColor = Color(0xFFFDBA74); // #FDBA74

  static Color colorForCategory(String c) {
    switch (c) {
      case TodoCategory.dine:
      case TodoCategory.acquire:
        return SpaceColors.neonPurple; // #A78BFA
      case TodoCategory.health:
      case TodoCategory.service:
        return SpaceColors.neonViolet; // #8B5CF6
      case TodoCategory.maintenance:
        return const Color(0xFFFDBA74); // #FDBA74
      case TodoCategory.social:
        return SpaceColors.neonPink; // #F472B6
      case TodoCategory.etc:
      default:
        return SpaceColors.neonPurple; // #A78BFA
    }
  }

  static String labelForCategory(String c) {
    switch (c) {
      case TodoCategory.dine:
        return '식사';
      case TodoCategory.acquire:
        return '구매';
      case TodoCategory.health:
        return '건강';
      case TodoCategory.service:
        return '업무';
      case TodoCategory.maintenance:
        return '정비';
      case TodoCategory.social:
        return '소셜';
      case TodoCategory.etc:
        return '기타';
      default:
        return '기타';
    }
  }

  static String hexForCategory(String c) {
    switch (c) {
      case TodoCategory.dine:
      case TodoCategory.acquire:
        return 'A78BFA';
      case TodoCategory.health:
      case TodoCategory.service:
        return '8B5CF6';
      case TodoCategory.maintenance:
        return 'FDBA74';
      case TodoCategory.social:
        return 'F472B6';
      case TodoCategory.etc:
      default:
        return 'A78BFA';
    }
  }
}

class _LoadingHint extends StatelessWidget {
  const _LoadingHint({
    required this.text,
    this.borderColor = const Color(0xFFA78BFA),
  });
  final String text;
  final Color borderColor;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 196,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE61A1A2E),
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Galmuri11',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSkeleton extends StatelessWidget {
  const _LocationSkeleton({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final shimmerCenter = (progress * 1.4) % 1.0;
    final start = (shimmerCenter - 0.25).clamp(0.0, 1.0);
    final end = (shimmerCenter + 0.25).clamp(0.0, 1.0);
    return Container(
      width: 104,
      height: 14,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, start, shimmerCenter, end, 1.0],
          colors: [
            SpaceColors.neonPurple.withValues(alpha: 0.36),
            SpaceColors.neonPurple.withValues(alpha: 0.56),
            SpaceColors.neonPurple.withValues(alpha: 0.86),
            SpaceColors.neonPurple.withValues(alpha: 0.56),
            SpaceColors.neonPurple.withValues(alpha: 0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _NodeLayoutData {
  const _NodeLayoutData({required this.angle, required this.radius});

  final double angle;
  final double radius;
}

class _RecommendLoadingSkeleton extends StatelessWidget {
  const _RecommendLoadingSkeleton({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        children: [
          _SkeletonCard(height: 90, progress: progress, progressOffset: 0.0),
          const SizedBox(height: 12),
          _SkeletonCard(height: 90, progress: progress, progressOffset: 0.2),
          const SizedBox(height: 12),
          _SkeletonCard(height: 90, progress: progress, progressOffset: 0.4),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
    required this.progress,
    required this.progressOffset,
  });
  final double height;
  final double progress;
  final double progressOffset;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin((progress + progressOffset) * math.pi * 2) + 1) / 2;
    final opacity = 0.26 + (0.28 * wave);
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: SpaceColors.space800.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceColors.neonPurple.withValues(alpha: 0.28 + (0.22 * wave)),
        ),
      ),
    );
  }
}
