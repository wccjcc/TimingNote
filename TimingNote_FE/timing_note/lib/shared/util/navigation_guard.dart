import 'package:flutter/material.dart';

/// State에 mixin해서 사용 — push/sheet/dialog 중복 트리거 방지.
///
/// 사용 예:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with NavigationGuardMixin {
///   void _onEdit() {
///     guardedRun(() async {
///       await context.push('/edit');
///     });
///   }
/// }
/// ```
///
/// `guardedRun` 내부의 async 작업이 진행 중이면 다시 호출돼도 즉시 return.
/// async 작업이 끝나면 자동으로 가드 해제. iOS 빠른 더블 탭으로 같은 화면 두 번 push되는
/// UX 버그 방지용.
mixin NavigationGuardMixin<T extends StatefulWidget> on State<T> {
  bool _navGuardBusy = false;

  /// async [action]을 한 번에 하나만 실행. 진행 중에 다시 호출되면 무시.
  /// action 종료 후 next frame까지 추가로 짧은 cooldown(50ms)을 둠 — Navigator pop 직후
  /// route stack 정리 frame과 다음 push 사이의 race를 추가로 방어.
  Future<void> guardedRun(Future<void> Function() action) async {
    if (_navGuardBusy) return;
    _navGuardBusy = true;
    try {
      await action();
    } finally {
      // 즉시 false로 풀면 동일 frame의 두 번째 탭이 통과 가능 — 다음 frame까지 차단.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _navGuardBusy = false;
      });
    }
  }

  /// 동기 액션용 — push(non-awaited)이나 showModalBottomSheet처럼 즉시 반환하는 호출.
  /// 50ms cooldown만 적용.
  void guardedRunSync(VoidCallback action) {
    if (_navGuardBusy) return;
    _navGuardBusy = true;
    action();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _navGuardBusy = false;
    });
  }
}
