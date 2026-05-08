import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'neon_button.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.title = '문제가 발생했어요',
    this.message = '잠시 후 다시 시도해 주세요.',
    this.retryLabel = '다시 시도',
    this.onRetry,
    this.compact = false,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: compact ? null : 320,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 22,
        vertical: compact ? 16 : 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xA61A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4DA78BFA)),
        boxShadow: [
          BoxShadow(
            color: SpaceColors.neonPurple.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 48 : 56,
                height: compact ? 48 : 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpaceColors.neonPink.withOpacity(0.14),
                  border: Border.all(color: SpaceColors.neonPink.withOpacity(0.45)),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: SpaceColors.neonPink,
                  size: 26,
                ),
              ),
              SizedBox(height: compact ? 12 : 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SpaceColors.white50,
                  fontSize: compact ? 13 : 14,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: compact ? 14 : 16),
                NeonButton(
                  label: retryLabel,
                  icon: Icons.refresh_rounded,
                  onTap: onRetry,
                  height: compact ? 46 : 50,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: card,
      ),
    );
  }
}
