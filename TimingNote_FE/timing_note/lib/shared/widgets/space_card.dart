import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SpaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? borderColor;

  const SpaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.blur = 12.0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: SpaceColors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? SpaceColors.white.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
