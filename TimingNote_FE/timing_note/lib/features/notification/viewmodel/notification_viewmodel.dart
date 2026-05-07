import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(NotificationFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> openNotification(NotificationItem item) async {
    if (item.isUnread) {
      await _service.applyAction(
        notificationId: item.id,
        actionType: 'OPEN',
      );
      await _service.markAsRead(item.id);
    }
    await load();
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
    await _service.deleteNotification(notificationId);
    await load();
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

