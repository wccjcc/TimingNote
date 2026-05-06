import 'package:flutter/material.dart';
import '../theme/colors.dart';

class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double height;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isPrimary = true,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isPrimary ? SpaceColors.neonPurple : SpaceColors.space700;
    final borderColor = isPrimary ? SpaceColors.neonViolet : SpaceColors.neonPurple.withOpacity(0.3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          color: onTap == null ? SpaceColors.white.withOpacity(0.05) : activeColor.withOpacity(isPrimary ? 1.0 : 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isPrimary && onTap != null
              ? [
                  BoxShadow(
                    color: SpaceColors.neonPurple.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: SpaceColors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? SpaceColors.white20 : SpaceColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
