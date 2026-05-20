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
    with TickerProviderStateMixin {
  // 자체 펄스(상하 진동) — 항상 반복
  late AnimationController _controller;
  // 탭 시 한 번 폭발 — 짧게 강해졌다가 천천히 사그라듦
  // forward 200ms → reverse 400ms로 "별이 반짝" 느낌. 자체 펄스와 독립 동작.
  late AnimationController _glowBoost;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowBoost = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowBoost.dispose();
    super.dispose();
  }

  /// 탭 → 글로우 폭발 트리거 + 부모 onTap 호출.
  /// forward 끝나는 즉시 reverse 시작 → 부드러운 in/out 곡선.
  /// 연속 탭하면 진행 중인 forward를 다시 0부터 시작 (시각적 누락 없음).
  void _handleTap() {
    _glowBoost.forward(from: 0.0).then((_) {
      if (mounted) _glowBoost.reverse();
    });
    widget.onTap();
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
      // 두 컨트롤러 변화 모두 rebuild 트리거 — 펄스(상하 진동) + 글로우 boost(탭 반응).
      animation: Listenable.merge([_controller, _glowBoost]),
      builder: (context, _) {
        // easeOut 곡선으로 boost 적용 — peak가 더 날카롭게 느껴짐.
        final boost = Curves.easeOut.transform(_glowBoost.value);
        // boxShadow 강조 계수: 평소 1.0, 탭 직후 최대 2.2배 blur + 2.5배 spread
        final blurMul = 1.0 + boost * 1.2;
        final spreadMul = 1.0 + boost * 1.5;
        // 별 본체 살짝 확대 (1.0 → 1.35) — 폭발감
        final starScale = 1.0 + boost * 0.35;

        return Transform.translate(
          offset: Offset(0, 10 * math.sin(_controller.value * 2 * math.pi)),
          child: FractionalTranslation(
            translation: const Offset(-0.5, 0),
            child: GestureDetector(
              onTap: _handleTap,
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
                        // 별 본체 — scale로 살짝 부풀고 글로우 boxShadow 강해짐.
                        // outer cross(+)는 scale 영향 X — 위치 안정성 유지.
                        Transform.scale(
                          scale: starScale,
                          child: Container(
                            width: starSize,
                            height: starSize,
                            decoration: BoxDecoration(
                              color: SpaceColors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.glowColor,
                                  blurRadius: 12 * blurMul,
                                  spreadRadius: 3 * spreadMul,
                                ),
                                BoxShadow(
                                  color: widget.glowColor
                                      .withOpacity(0.4 + 0.5 * boost),
                                  blurRadius: 24 * blurMul,
                                  spreadRadius: 8 * spreadMul,
                                ),
                              ],
                            ),
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
                            // 라벨 border도 boost — 별과 함께 라벨 박스 외곽도 잠시 환해짐
                            border: Border.all(
                              color: widget.glowColor
                                  .withOpacity(0.3 + 0.5 * boost),
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
                                // 텍스트 그림자 글로우도 boost — 글자도 잠시 빛남
                                Shadow(
                                  color: widget.glowColor,
                                  blurRadius: 12 + 12 * boost,
                                ),
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
      },
    );
  }
}
