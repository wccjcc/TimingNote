import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 짧은 행위 결과(성공/오류/안내)를 화면 상단에서 슬라이드다운으로 알려주는 토스트.
///
/// Material `SnackBar`(하단 흰색 바)를 우주 테마와 iOS HIG에 맞게 대체한다.
/// - 상단 anchored: iOS 노티피케이션 멘탈 모델과 일치, 탭바/키보드와 충돌하지 않음
/// - Glassmorphism: SpaceCard와 동일한 결의 블러 + 보더
/// - kind 별 색상: success = neonViolet, error = error, info = neonLavender
/// - 자동 해제 + 탭으로 즉시 해제
///
/// 사용:
/// ```dart
/// SpaceToast.show(context, message: '저장되었어요');
/// SpaceToast.show(context, message: '실패했어요', kind: ToastKind.error);
/// ```
enum ToastKind { success, error, info }

class SpaceToast {
  SpaceToast._();

  static OverlayEntry? _entry;

  /// 새 토스트 표시. 이미 떠 있는 토스트는 즉시 제거되고 새 토스트로 교체된다.
  static void show(
    BuildContext context, {
    required String message,
    ToastKind kind = ToastKind.success,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _hardDismiss();

    final entry = OverlayEntry(
      builder: (_) => _SpaceToastView(
        message: message,
        kind: kind,
        duration: duration,
        onDone: _hardDismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void _hardDismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _SpaceToastView extends StatefulWidget {
  const _SpaceToastView({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final ToastKind kind;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_SpaceToastView> createState() => _SpaceToastViewState();
}

class _SpaceToastViewState extends State<_SpaceToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideY;
  late final Animation<double> _opacity;
  Timer? _autoHide;
  bool _hiding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slideY = Tween<double>(begin: -28, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _autoHide = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (_hiding) return;
    _hiding = true;
    _autoHide?.cancel();
    if (!mounted) return;
    try {
      await _controller.reverse();
    } catch (_) {
      // 화면이 먼저 사라지면 controller가 파기될 수 있음 — 무시
    }
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: child,
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hide,
          child: _ToastBody(message: widget.message, kind: widget.kind),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message, required this.kind});

  final String message;
  final ToastKind kind;

  Color get _accent => switch (kind) {
        ToastKind.success => SpaceColors.neonViolet,
        ToastKind.error => SpaceColors.error,
        ToastKind.info => SpaceColors.neonLavender,
      };

  IconData get _icon => switch (kind) {
        ToastKind.success => Icons.check_circle_outline,
        ToastKind.error => Icons.error_outline,
        ToastKind.info => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    // Overlay에 직접 띄우면 Material 조상이 없어 Text에 노란 더블 언더라인이 그려진다.
    // Material(transparency) 또는 DefaultTextStyle로 텍스트 환경을 명시해야 한다.
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: SpaceColors.space900.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: SpaceColors.space950.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(_icon, color: _accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: SpaceColors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      decoration: TextDecoration.none,
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
