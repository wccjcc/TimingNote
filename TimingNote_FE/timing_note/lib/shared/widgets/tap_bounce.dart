import 'package:flutter/material.dart';

/// 탭 시 살짝 작아졌다 spring으로 복귀하는 클릭 피드백 wrapper.
///
/// 카드/큰 버튼 위에 GestureDetector 역할로 사용. onTap이 null이면 시각도 비활성.
///
/// 사용 예:
/// ```dart
/// TapBounce(
///   onTap: () => context.push('/detail'),
///   child: Container(
///     padding: const EdgeInsets.all(16),
///     child: Text('카드 내용'),
///   ),
/// );
/// ```
///
/// InkWell의 ripple과 함께 써도 무관 — scale은 외곽 transform, ripple은 표면 paint.
/// 다만 단순 GestureDetector + scale만으로 충분한 케이스(다크 톤 카드)에선
/// InkWell을 빼고 TapBounce만 사용하는 편이 톤 일관성 좋음.
class TapBounce extends StatefulWidget {
  const TapBounce({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 90),
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool v) {
    if (!mounted || !_enabled) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? widget.pressedScale : 1.0;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: _enabled ? widget.onTap : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: widget.duration,
        // 누를 때는 빠르게 작아지고(easeOut), 뗄 때는 살짝 튕기는 spring 느낌(elasticOut은 과함 → easeOutBack)
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
