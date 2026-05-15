import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 우주 테마 네온 버튼.
///
/// 인터랙션:
/// - 누르는 동안 scale 0.97로 살짝 작아짐 (TapBounce와 동일 톤)
/// - 누르는 동안 글로우(boxShadow) blur 12 → 24, opacity 0.4 → 0.7로 강해짐
/// - 손 떼면 spring으로 1.0 복귀 (easeOutBack curve) + 글로우 부드럽게 원상복귀
/// - onTap=null이면 자동 비활성 시각(회색) + 인터랙션 무반응
///
/// secondary 모드(isPrimary=false)는 글로우 없음 — 보조 버튼이라 강조 약하게.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double height;
  final double fontSize;
  final String? fontFamily;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isPrimary = true,
    this.height = 54,
    this.fontSize = 16,
    this.fontFamily,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool v) {
    if (!_enabled || !mounted) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.isPrimary ? SpaceColors.neonPurple : SpaceColors.space700;
    final borderColor = widget.isPrimary
        ? SpaceColors.neonViolet
        : SpaceColors.neonPurple.withOpacity(0.3);

    // 누름 상태에 따른 글로우 강조 계수
    final showGlow = widget.isPrimary && _enabled;
    final glowBlur = _pressed ? 24.0 : 12.0;
    final glowSpread = _pressed ? 2.0 : 0.0;
    final glowOpacity = _pressed ? 0.7 : 0.4;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? widget.onTap : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        // 누름은 빠르게, 떼는 순간 spring 살짝 튕김 (easeOutBack)
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: widget.height,
          decoration: BoxDecoration(
            color: _enabled
                ? activeColor.withOpacity(widget.isPrimary ? 1.0 : 0.8)
                : SpaceColors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: showGlow
                ? [
                    BoxShadow(
                      color: SpaceColors.neonPurple
                          .withOpacity(glowOpacity),
                      blurRadius: glowBlur,
                      spreadRadius: glowSpread,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: SpaceColors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _enabled
                          ? SpaceColors.white
                          : SpaceColors.white20,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.fontSize,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
