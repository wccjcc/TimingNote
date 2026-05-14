import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/colors.dart';
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
  });

  final String currentLocationLabel;

  @override
  State<HomeRecommendSection> createState() => _HomeRecommendSectionState();
}

class _HomeRecommendSectionState extends State<HomeRecommendSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _activeIndex;
  final Set<int> _removingIds = <int>{};
  static const double _currentLat = 35.1530;
  static const double _currentLng = 126.8526;

  static const List<_RecommendItem> _seedItems = <_RecommendItem>[
    _RecommendItem(
      id: 1,
      category: TodoCategory.acquire,
      place: 'Nearby Cafe',
      title: 'Buy cat snacks',
      distanceMeters: 120,
      placeLat: 35.1542,
      placeLng: 126.8566,
      accent: _CategoryPalette.acquireColor,
    ),
    _RecommendItem(
      id: 2,
      category: TodoCategory.social,
      place: 'Town Hall',
      title: 'Call teammate',
      distanceMeters: 280,
      placeLat: 35.1504,
      placeLng: 126.8495,
      accent: _CategoryPalette.socialColor,
    ),
    _RecommendItem(
      id: 3,
      category: TodoCategory.health,
      place: 'Park',
      title: 'Take a short walk',
      distanceMeters: 60,
      placeLat: 35.1524,
      placeLng: 126.8548,
      accent: _CategoryPalette.healthColor,
    ),
    _RecommendItem(
      id: 4,
      category: TodoCategory.maintenance,
      place: 'Convenience Store',
      title: 'Buy tissue',
      distanceMeters: 320,
      placeLat: 35.1499,
      placeLng: 126.8532,
      accent: _CategoryPalette.maintenanceColor,
    ),
  ];

  List<_RecommendItem> _items = List<_RecommendItem>.from(_seedItems);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapNode(int index) {
    setState(() => _activeIndex = _activeIndex == index ? null : index);
  }

  Future<void> _onTapCompleteItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (_removingIds.contains(item.id)) return;

    // TODO: 완료 API 연결 지점
    // - 예시: await _completeRecommendation(item.id);
    // - 현재는 UI 동작 검증을 위해 즉시 성공으로 처리한다.
    await _completeRecommendation(item.id);

    setState(() {
      _removingIds.add(item.id);
      if (_activeIndex == index) _activeIndex = null;
    });

    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() {
        final removeIndex = _items.indexWhere((e) => e.id == item.id);
        if (removeIndex >= 0) _items.removeAt(removeIndex);
        _removingIds.remove(item.id);
      });
    });
  }

  Future<void> _completeRecommendation(int todoId) async {
    // TODO: 백엔드 완료 API 연결
    // 예시:
    // await ref.read(recommendRepositoryProvider).complete(todoId);
    await Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final maxDistance = _items.isEmpty
            ? 1.0
            : _items
                .map((e) => e.distanceMeters)
                .reduce((a, b) => a > b ? a : b)
                .toDouble();
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
                    Text(
                      widget.currentLocationLabel,
                      style: TextStyle(
                        color: SpaceColors.neonPurple.withOpacity(0.8),
                        fontSize: 11,
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
                        child: _CenterPlanet(progress: progress),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: _activeIndex == null,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _activeIndex = null),
                          ),
                        ),
                      ),
                        ...[
                          ...List.generate(_items.length, (i) {
                            if (_activeIndex == i) return const SizedBox.shrink();
                            final item = _items[i];
                            final bearingDeg = _calculateBearingDegrees(
                              fromLat: _currentLat,
                              fromLng: _currentLng,
                              toLat: item.placeLat,
                              toLng: item.placeLng,
                            );
                            return _NodeStub(
                              key: ValueKey(item.id),
                              isRemoving: _removingIds.contains(item.id),
                              isActive: false,
                              angle: (bearingDeg * math.pi / 180) - (math.pi / 2),
                              radius: (() {
                                final t = (item.distanceMeters / maxDistance).clamp(0.0, 1.0);
                                final normalized = 0.28 + (0.72 * t);
                                return 72 + ((138 - 72) * normalized);
                              })(),
                              centerX: 160,
                              centerY: 160,
                              color: _CategoryPalette.colorForCategory(item.category),
                              image:
                                  'assets/images/paw_node_${_CategoryPalette.hexForCategory(item.category)}.png',
                              placeLabel: item.place,
                              distanceLabel: _formatDistance(item.distanceMeters),
                              floatPhase: (progress * math.pi * 2) + (i * 0.9),
                              onTap: () => _onTapNode(i),
                            );
                          }),
                          if (_activeIndex != null && _activeIndex! >= 0 && _activeIndex! < _items.length)
                            (() {
                              final i = _activeIndex!;
                              final item = _items[i];
                              final bearingDeg = _calculateBearingDegrees(
                                fromLat: _currentLat,
                                fromLng: _currentLng,
                                toLat: item.placeLat,
                                toLng: item.placeLng,
                              );
                              return _NodeStub(
                                key: ValueKey(item.id),
                                isRemoving: _removingIds.contains(item.id),
                                isActive: true,
                                angle: (bearingDeg * math.pi / 180) - (math.pi / 2),
                                radius: (() {
                                  final t = (item.distanceMeters / maxDistance).clamp(0.0, 1.0);
                                  final normalized = 0.28 + (0.72 * t);
                                  return 72 + ((138 - 72) * normalized);
                                })(),
                                centerX: 160,
                                centerY: 160,
                                color: _CategoryPalette.colorForCategory(item.category),
                                image:
                                    'assets/images/paw_node_${_CategoryPalette.hexForCategory(item.category)}.png',
                                placeLabel: item.place,
                                distanceLabel: _formatDistance(item.distanceMeters),
                                floatPhase: (progress * math.pi * 2) + (i * 0.9),
                                onTap: () => _onTapNode(i),
                              );
                            })(),
                        ],
                      if (_items.isEmpty) const _EmptyHint(),
                      ],
                    ),
                  ),
                ),
              ),
              if (_activeIndex != null && _activeIndex! < _items.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _ActivePlaceInfo(
                    place: _items[_activeIndex!].place,
                    distance: _formatDistance(_items[_activeIndex!].distanceMeters),
                    color: _CategoryPalette.colorForCategory(
                      _items[_activeIndex!].category,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    return _CardStub(
                      key: ValueKey(item.id),
                      item: item,
                      isActive: _activeIndex == i,
                      isRemoving: _removingIds.contains(item.id),
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
  const _CenterPlanet({required this.progress});
  final double progress;
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
                    color: SpaceColors.neonPurple.withOpacity(0.16),
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
                    color: SpaceColors.neonViolet.withOpacity(0.14),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            ClipOval(
              child: Image.asset('assets/images/nyang_star_1.png', width: 86, height: 86),
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
                        color: widget.color.withOpacity(widget.isActive ? 0.52 : 0.34),
                        blurRadius: widget.isActive ? 18 : 12,
                        spreadRadius: widget.isActive ? 2 : 1,
                      ),
                    ],
                  ),
                  child: ClipOval(child: Image.asset(widget.image, fit: BoxFit.cover)),
                ),
                if (widget.isActive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SpaceColors.space900.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.color.withOpacity(0.7)),
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
  final _RecommendItem item;
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
                ? categoryColor.withOpacity(0.20)
                : SpaceColors.space800.withOpacity(0.64),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? categoryColor.withOpacity(0.9)
                  : categoryColor.withOpacity(0.35),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withOpacity(isActive ? 0.30 : 0.20),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: categoryColor.withOpacity(0.55)),
                    ),
                    child: Text(
                      _CategoryPalette.labelForCategory(item.category),
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Galmuri11',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
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
                      backgroundColor: SpaceColors.neonPurple.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: SpaceColors.neonPurple.withOpacity(0.78)),
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
        color: SpaceColors.space900.withOpacity(0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.7)),
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
          border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.20), width: 1),
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
                SpaceColors.neonPurple.withOpacity(0.0),
                SpaceColors.neonPurple.withOpacity(0.09 * opacityFactor),
                SpaceColors.neonPurple.withOpacity(0.30 * opacityFactor),
              ],
              stops: const [0.0, 0.68, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceColors.neonPurple.withOpacity(0.42 * opacityFactor),
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

class _RecommendItem {
  const _RecommendItem({
    required this.id,
    required this.category,
    required this.place,
    required this.title,
    required this.distanceMeters,
    required this.placeLat,
    required this.placeLng,
    required this.accent,
  });
  final int id;
  final String category;
  final String place;
  final String title;
  final double distanceMeters;
  final double placeLat;
  final double placeLng;
  final Color accent;
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
