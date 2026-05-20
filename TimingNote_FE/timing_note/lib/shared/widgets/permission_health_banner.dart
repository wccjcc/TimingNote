import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permission/permission_health_provider.dart';
import '../theme/colors.dart';

class PermissionHealthInlineNotice extends ConsumerWidget {
  const PermissionHealthInlineNotice({
    super.key,
    this.margin = EdgeInsets.zero,
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(permissionBannerDismissedProvider);
    if (dismissed) {
      return const SizedBox.shrink();
    }

    final health = ref.watch(permissionHealthProvider);
    return health.maybeWhen(
      data: (value) {
        if (!value.hasWarning) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: margin,
          child: PermissionHealthBanner(
            health: value,
            onTap: () => context.go('/my'),
            onDismiss: () {
              ref.read(permissionBannerDismissedProvider.notifier).state = true;
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class PermissionHealthBanner extends StatelessWidget {
  const PermissionHealthBanner({
    super.key,
    required this.health,
    required this.onTap,
    required this.onDismiss,
  });

  final PermissionHealth health;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: SpaceColors.space900.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SpaceColors.neonYellow.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: SpaceColors.neonYellow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: SpaceColors.neonYellow,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      health.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SpaceColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      health.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SpaceColors.white.withOpacity(0.58),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.close,
                  color: SpaceColors.white.withOpacity(0.46),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
