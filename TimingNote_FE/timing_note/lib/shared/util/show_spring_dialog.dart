import 'package:flutter/material.dart';

/// Material `showDialog` 의 단순 fade entrance를 spring scale로 교체.
///
/// 0.85 → 1.0 scale을 easeOutBack 곡선으로 살짝 overshoot → "탁" 자리잡는 느낌.
/// fade는 easeOut으로 동시 진행, 280ms로 빠르게.
///
/// 사용:
/// ```dart
/// final ok = await showSpringDialog<bool>(
///   context: context,
///   builder: (ctx) => AlertDialog(...),
/// );
/// ```
///
/// 시그니처는 `showDialog<T>`와 거의 동일 — 호출자 코드 1단어(`showDialog` → `showSpringDialog`)만 치환.
Future<T?> showSpringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Duration transitionDuration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: transitionDuration,
    pageBuilder: (context, _, __) => Builder(builder: builder),
    transitionBuilder: (context, anim, _, child) {
      final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}
