import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../model/notification_item.dart';
import '../viewmodel/notification_viewmodel.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    ref.listen<NotificationState>(notificationProvider, (prev, next) {
      final error = next.error;
      final isInitialBlockingError = next.items.isEmpty;
      if (error != null && error != prev?.error && !isInitialBlockingError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                onBack: () => Navigator.of(context).maybePop(),
                onMarkAllRead: () {
                  // TODO: 벌크 읽음 API(전체 읽음) 추가 후 실제 연동으로 교체
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('전체 읽음 기능은 추후 개발 예정입니다.')),
                  );
                },
                onClearAll: () {
                  // TODO: 벌크 삭제 API(전체 삭제) 추가 후 실제 연동으로 교체
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('전체 삭제 기능은 추후 개발 예정입니다.')),
                  );
                },
                currentFilter: state.filter,
                onChangeFilter: (next) {
                  ref.read(notificationProvider.notifier).setFilter(next);
                },
              ),
              Expanded(
                child: state.isLoading && state.items.isEmpty
                    ? const AppLoadingView(message: '알림 데이터를 동기화하는 중...')
                    : state.error != null && state.items.isEmpty
                        ? AppErrorView(
                            title: '알림을 불러오지 못했어요',
                            message: state.error!,
                            onRetry: () => ref.read(notificationProvider.notifier).load(),
                          )
                        : state.filteredItems.isEmpty
                        ? const _EmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: state.filteredItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = state.filteredItems[index];
                              return _NotificationCard(
                                item: item,
                                onTap: () async {
                                  // 상세 이동은 사용자 액션의 핵심 경로이므로 우선 보장합니다.
                                  final todoId = item.todoId;
                                  if (todoId != null) {
                                    context.push('/todos/$todoId');
                                  }

                                  // 읽음 처리/OPEN 액션은 실패해도 화면 이동을 막지 않도록 분리합니다.
                                  try {
                                    await ref.read(notificationProvider.notifier).openNotification(item);
                                    ref.invalidate(unreadNotificationCountProvider);
                                  } catch (_) {
                                    // 목록/배지 동기화 실패는 사용자 이동 UX를 막지 않습니다.
                                  }
                                },
                                onDelete: () {
                                  ref.read(notificationProvider.notifier).deleteOne(item.id).then((_) {
                                    ref.invalidate(unreadNotificationCountProvider);
                                  });
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onMarkAllRead,
    required this.onClearAll,
    required this.currentFilter,
    required this.onChangeFilter,
  });

  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;
  final NotificationFilter currentFilter;
  final ValueChanged<NotificationFilter> onChangeFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: SpaceColors.space950.withOpacity(0.85),
        border: const Border(bottom: BorderSide(color: SpaceColors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  '알림함',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: SpaceTypography.pixelFontFamily,
                  ),
                ),
              ),
              TextButton(
                onPressed: onMarkAllRead,
                child: const Text(
                  '전체 읽음',
                  style: TextStyle(
                    color: SpaceColors.neonLavender,
                    fontSize: 12,
                    fontFamily: SpaceTypography.pixelFontFamily,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(
                    color: SpaceColors.neonPink,
                    fontSize: 12,
                    fontFamily: SpaceTypography.pixelFontFamily,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterTab(
                label: '전체',
                active: currentFilter == NotificationFilter.all,
                onTap: () => onChangeFilter(NotificationFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterTab(
                label: '읽지 않음',
                active: currentFilter == NotificationFilter.unread,
                onTap: () => onChangeFilter(NotificationFilter.unread),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: active ? SpaceColors.neonPurple.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? SpaceColors.neonPurple : SpaceColors.neonPurple.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : SpaceColors.neonPurple.withOpacity(0.55),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: SpaceTypography.pixelFontFamily,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (item.notificationType) {
      case 'SPECIFIC':
        return Icons.location_on_outlined;
      case 'GENERIC':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = BoxDecoration(
      color: item.isUnread
          ? SpaceColors.neonPurple.withOpacity(0.09)
          : SpaceColors.space800.withOpacity(0.45),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: item.isUnread
            ? SpaceColors.neonPurple.withOpacity(0.35)
            : SpaceColors.neonPurple.withOpacity(0.10),
      ),
    );

    final createdAt = item.createdAt?.toLocal();
    final timeLabel = createdAt == null
        ? ''
        : '${createdAt.month}/${createdAt.day} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Opacity(
      opacity: item.isUnread ? 1.0 : 0.65,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: base,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SpaceColors.neonPurple.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.3)),
                  ),
                  child: Icon(_icon, color: SpaceColors.neonPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title ?? '(제목 없음)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: SpaceTypography.pixelFontFamily,
                              ),
                            ),
                          ),
                          if (timeLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                color: SpaceColors.white50,
                                fontSize: 10,
                                fontFamily: SpaceTypography.pixelFontFamily,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body ?? '',
                        style: const TextStyle(
                          color: SpaceColors.white50,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: SpaceTypography.pixelFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, color: SpaceColors.white50, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_outlined, color: SpaceColors.neonPurple, size: 48),
          SizedBox(height: 10),
          Text(
            '새 알림이 없습니다',
            style: TextStyle(
              color: SpaceColors.white50,
              fontSize: 14,
              fontFamily: SpaceTypography.pixelFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
