import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/core/network/api_exception.dart';

import '../model/notification_item.dart';
import '../service/notification_service.dart';

enum NotificationFilter { all, unread }

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.filter = NotificationFilter.all,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;
  final NotificationFilter filter;

  List<NotificationItem> get filteredItems {
    if (filter == NotificationFilter.all) return items;
    return items.where((e) => e.isUnread).toList();
  }

  NotificationState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
    NotificationFilter? filter,
  }) {
    return NotificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  late final NotificationService _service;

  /// 진행 중인 항목별 액션 — 같은 알림 더블 탭 시 두 번째 호출 차단.
  /// open/delete 별도로 관리하면 복잡하니 하나의 Set으로 통합.
  final Set<int> _inflightItemActions = <int>{};

  @override
  NotificationState build() {
    _service = ref.read(notificationServiceProvider);
    Future.microtask(load);
    return const NotificationState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _service.getNotifications(page: 0, size: 100);
      state = state.copyWith(isLoading: false, items: page.content);
    } catch (e) {
      var message = '알림 정보를 불러오지 못했어요.';
      if (e is ApiException) {
        if (e.statusCode == 404 && e.message.trim().isNotEmpty) {
          message = e.message;
        } else if (e.code == 'NETWORK_ERROR') {
          message = '서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.';
        }
      }
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  void setFilter(NotificationFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> openNotification(NotificationItem item) async {
    // 더블 탭 가드 — 같은 알림 카드 빠르게 두 번 탭 시 BE applyAction + markAsRead 중복 호출 방지.
    if (!_inflightItemActions.add(item.id)) return;
    try {
      if (item.isUnread) {
        await _service.applyAction(
          notificationId: item.id,
          actionType: 'OPEN',
        );
        await _service.markAsRead(item.id);
      }
      await load();
    } finally {
      _inflightItemActions.remove(item.id);
    }
  }

  Future<void> markAllRead() async {
    final unread = state.items.where((e) => e.isUnread).toList();
    if (unread.isEmpty) return;
    for (final item in unread) {
      await _service.markAsRead(item.id);
    }
    await load();
  }

  Future<void> deleteOne(int notificationId) async {
    if (!_inflightItemActions.add(notificationId)) return;
    try {
      await _service.deleteNotification(notificationId);
      await load();
    } finally {
      _inflightItemActions.remove(notificationId);
    }
  }

  Future<void> clearAll() async {
    final ids = state.items.map((e) => e.id).toList();
    for (final id in ids) {
      await _service.deleteNotification(id);
    }
    await load();
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(notificationServiceProvider);
  final page = await service.getNotifications(page: 0, size: 100);
  return page.content.where((e) => e.isUnread).length;
});

