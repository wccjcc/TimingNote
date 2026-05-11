import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FloatingStarTag extends StatefulWidget {
  final String label;
  final Color glowColor;
  final VoidCallback onTap;
  final bool small;

  const FloatingStarTag({
    super.key,
    required this.label,
    required this.glowColor,
    required this.onTap,
    this.small = false,
  });

  @override
  State<FloatingStarTag> createState() => _FloatingStarTagState();
}

class _FloatingStarTagState extends State<FloatingStarTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 라벨 최대 폭 — 별 중심을 anchor로 했을 때 좌우로 펴지는 거리(이 값/2)가
  // 같은 행의 다른 별과 겹치지 않게 충분히 작아야 한다. 초과 시 ellipsis.
  static const double _kLabelMaxWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    final double starSize = widget.small ? 4.0 : 4.6;
    final double crossSize = widget.small ? 20.0 : 23.0;

    // 위젯의 layout 박스는 (라벨 폭 최대 _kLabelMaxWidth) x (별+간격+라벨 높이).
    // FractionalTranslation(-0.5, 0)으로 자기 폭의 절반만큼 왼쪽으로 평행이동시키면,
    // 부모(Positioned)가 가리키는 X가 위젯의 "중심"이 된다. Column 안에서 별과 라벨이
    // 모두 중앙 정렬이므로 anchor = 별 중심 = 라벨 중심 → 라벨 길이가 달라도 별 격자 안정.
    // hit area는 Column 박스 전체(별+라벨) → 글자 탭도 onTap이 호출된다.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 10 * math.sin(_controller.value * 2 * math.pi)),
          child: child,
        );
      },
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: crossSize,
                height: crossSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: crossSize,
                      height: 1.15,
                      color: SpaceColors.white.withOpacity(0.5),
                    ),
                    Container(
                      width: 1.15,
                      height: crossSize,
                      color: SpaceColors.white.withOpacity(0.5),
                    ),
                    Container(
                      width: starSize,
                      height: starSize,
                      decoration: BoxDecoration(
                        color: SpaceColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.glowColor,
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: widget.glowColor.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kLabelMaxWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SpaceColors.space900.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.glowColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SpaceColors.white.withOpacity(0.9),
                          fontSize: widget.small ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            const Shadow(color: Colors.black, blurRadius: 6),
                            Shadow(color: widget.glowColor, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
