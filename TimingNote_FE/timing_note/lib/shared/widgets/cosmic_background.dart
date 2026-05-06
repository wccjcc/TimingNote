import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CosmicBackground extends StatelessWidget {
  final Widget child;

  const CosmicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: Deep Space Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                SpaceColors.space900,
                SpaceColors.space950,
              ],
            ),
          ),
        ),
        // LAYER 2: Twinkling Stars
        const _StarField(),
        // LAYER 3: Content
        child,
      ],
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(),
      size: Size.infinite,
    );
  }
}

class _StarPainter extends CustomPainter {
  static final _rng = math.Random(42);
  static final List<_StarData> _stars = List.generate(
    60,
    (_) => _StarData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      radius: _rng.nextDouble() * 1.5 + 0.5,
      opacity: _rng.nextDouble() * 0.3 + 0.1,
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in _stars) {
      paint.color = (star.x > 0.5 ? SpaceColors.neonPurple : SpaceColors.white)
          .withOpacity(star.opacity);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

class _StarData {
  final double x, y, radius, opacity;
  const _StarData({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
}
