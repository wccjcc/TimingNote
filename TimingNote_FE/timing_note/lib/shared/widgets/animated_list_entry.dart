import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 리스트 항목의 첫 등장 시 아래에서 fade-up으로 stagger 등장하는 wrapper.
///
/// 사용 예:
/// ```dart
/// ListView.builder(
///   itemBuilder: (_, i) => AnimatedListEntry(
///     index: i,
///     child: MyCard(...),
///   ),
/// );
/// ```
///
/// - index 기반 stagger: 첫 등장 시점이 index * delayPerItem 만큼 밀려
///   카드들이 차례로 등장하는 인상을 줌.
/// - maxStaggerCount: 너무 많은 항목 대기 방지. N개 넘으면 동시 등장.
/// - 한 번 등장 후엔 정적 — 스크롤로 다시 등장하지 않음.
class AnimatedListEntry extends StatefulWidget {
  const AnimatedListEntry({
    super.key,
    required this.child,
    required this.index,
    this.delayPerItem = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 380),
    this.offsetY = 18.0,
    this.maxStaggerCount = 8,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final int index;
  final Duration delayPerItem;
  final Duration duration;
  final double offsetY;
  final int maxStaggerCount;
  final Curve curve;

  @override
  State<AnimatedListEntry> createState() => _AnimatedListEntryState();
}

class _AnimatedListEntryState extends State<AnimatedListEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    final delay = widget.delayPerItem *
        math.min(widget.index, widget.maxStaggerCount);
    // 첫 빌드 직후 delay 후 시작 — postFrameCallback 없이도 Future.delayed면 충분
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value; // 0.0 → 1.0
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
