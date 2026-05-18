import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 딥 스페이스 베이스 그라데이션과 은은한 픽셀 아트 별빛이 적용된 배경 위젯.
class CosmicBackground extends StatelessWidget {
  final Widget child;

  const CosmicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: 딥 스페이스 베이스
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF04040C),
                  Color(0xFF0A081A),
                  Color(0xFF04040C),
                ],
              ),
            ),
          ),
        ),
        
        // LAYER 2: 은은한 픽셀 아트 별 필드 (전체 화면 채움)
        const Positioned.fill(child: _SubtlePixelStarField()),
        
        // LAYER 3: 실제 화면 컨텐츠
        child,
      ],
    );
  }
}

class _SubtlePixelStarField extends StatefulWidget {
  const _SubtlePixelStarField();

  @override
  State<_SubtlePixelStarField> createState() => _SubtlePixelStarFieldState();
}

class _SubtlePixelStarFieldState extends State<_SubtlePixelStarField> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // 전체적인 호흡
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _PixelStarPainter(_controller.value),
        );
      },
    );
  }
}

class _PixelStarPainter extends CustomPainter {
  final double animationValue;
  _PixelStarPainter(this.animationValue);

  static final _rng = math.Random(99);
  
  // 별 데이터 생성 (화면 전체 채움)
  static final List<_StarInfo> _stars = List.generate(110, (_) {
    final x = _rng.nextDouble();
    final y = _rng.nextDouble();

    final sizeType = _rng.nextInt(10);
    final pixelSize = (_rng.nextDouble() * 2.0 + 2.0).floorToDouble(); 
    
    // 기본 투명도 범위
    final baseOpacity = _rng.nextDouble() * 0.2 + 0.1;
    
    Color color;
    if (_rng.nextDouble() > 0.7) {
      color = const Color(0xFFBAE6FD);
    } else {
      color = Colors.white;
    }

    return _StarInfo(
      x: x, 
      y: y, 
      pixelSize: pixelSize, 
      color: color,
      baseOpacity: baseOpacity,
      isCross: sizeType > 7,
      // 반짝임 속도를 정수로 설정하여 10초 루프가 끝날 때 부드럽게 이어지도록 수정
      twinkleSpeed: (_rng.nextInt(3) + 2).toDouble(), // 2, 3, 4 중 하나의 정수 주기
      twinklePhase: _rng.nextDouble() * 2 * math.pi, 
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    for (final star in _stars) {
      // 시간(animationValue)에 따른 부드러운 사인파 투명도 계산
      // (sin + 1) / 2 를 통해 0~1 사이의 값으로 변환
      final sinVal = math.sin((animationValue * 2 * math.pi * star.twinkleSpeed) + star.twinklePhase);
      final twinkleFactor = (sinVal + 1) / 2;
      
      // 최종 투명도: 기본 투명도에 반짝임 계수 적용 (최소 20%는 남겨서 완전히 사라지지 않게 함)
      final currentOpacity = star.baseOpacity * (0.2 + 0.8 * twinkleFactor);
      paint.color = star.color.withOpacity(currentOpacity);
      
      final center = Offset(star.x * size.width, star.y * size.height);
      
      if (star.isCross) {
        final p = star.pixelSize;
        canvas.drawRect(Rect.fromCenter(center: center, width: p * 3, height: p), paint);
        canvas.drawRect(Rect.fromCenter(center: center, width: p, height: p * 3), paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: center, width: star.pixelSize, height: star.pixelSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelStarPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}

class _StarInfo {
  final double x, y, pixelSize, baseOpacity, twinkleSpeed, twinklePhase;
  final Color color;
  final bool isCross;
  _StarInfo({
    required this.x, 
    required this.y, 
    required this.pixelSize, 
    required this.color, 
    required this.baseOpacity,
    required this.isCross,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });
}

