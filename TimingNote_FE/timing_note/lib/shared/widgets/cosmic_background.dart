import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 라이브러리 없이 CustomPainter만으로 구현한 고도로 정교한 오로라 & 별빛 배경.
/// 
/// 핵심 구현 사항:
/// 1. 오로라 파동(Aurora Waves): 라이브러리의 다중 사인파 공식을 수평 흐름(좌->우)에 맞게 재해석하여 직접 구현.
/// 2. 3중 레이어 십자별(Bloom Stars): 코어 점 + 중간 광후 + 넓은 외곽광을 겹쳐 그려 실제 발광 효과 연출.
/// 3. 완전한 통제: 모든 농도, 속도, 블러 강도를 라이브러리 제약 없이 1px 단위로 조정.
class CosmicBackground extends StatelessWidget {
  final Widget child;

  const CosmicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: 딥 스페이스 베이스 (깊이감 있는 그라데이션)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF04040C), // 극도로 깊은 네이비
                  Color(0xFF0A081A), // 깊은 바이올렛
                  Color(0xFF04040C),
                ],
              ),
            ),
          ),
        ),
        
        // LAYER 2: 수평으로 흐르는 다중 오로라 파동 (CustomPainter로 직접 구현)
        const Positioned.fill(child: _CustomAuroraFlow()),
        
        // LAYER 3: 우아하게 숨쉬는 3중 글로우 십자별
        const Positioned.fill(child: _CustomTwinklingStars()),
        
        // LAYER 4: 실제 화면 컨텐츠
        child,
      ],
    );
  }
}

/// 라이브러리의 오로라 로직을 커스텀 구현한 클래스
class _CustomAuroraFlow extends StatefulWidget {
  const _CustomAuroraFlow();

  @override
  State<_CustomAuroraFlow> createState() => _CustomAuroraFlowState();
}

class _CustomAuroraFlowState extends State<_CustomAuroraFlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // 오로라 특유의 느릿한 흐름
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
        return SizedBox.expand(
          child: CustomPaint(
            painter: _AuroraPainter(_controller.value),
          ),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double animationValue;
  _AuroraPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    // 블러를 높여 경계가 없는 성운 느낌 연출
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    
    // 세 겹의 오로라 파동을 각각 다른 주파수와 색상으로 그림
    // 1번 파동: 네온 퍼플 베이스
    _drawAuroraWave(canvas, size, paint, 
      colors: [SpaceColors.neonPurple.withOpacity(0.08), SpaceColors.neonPurple.withOpacity(0.15), SpaceColors.neonPurple.withOpacity(0.08)],
      yOffset: size.height * 0.4,
      waveHeight: 120,
      frequency: 2.0,
      speed: 1.0);

    // 2번 파동: 네온 바이올렛 베이스
    _drawAuroraWave(canvas, size, paint, 
      colors: [SpaceColors.neonViolet.withOpacity(0.06), SpaceColors.neonViolet.withOpacity(0.12), SpaceColors.neonViolet.withOpacity(0.06)],
      yOffset: size.height * 0.6,
      waveHeight: 100,
      frequency: 1.5,
      speed: 0.7);

    // 3번 파동: 소프트 사이안 베이스
    _drawAuroraWave(canvas, size, paint, 
      colors: [const Color(0xFF60A5FA).withOpacity(0.04), const Color(0xFF60A5FA).withOpacity(0.08), const Color(0xFF60A5FA).withOpacity(0.04)],
      yOffset: size.height * 0.75,
      waveHeight: 80,
      frequency: 2.5,
      speed: 1.2);
  }

  /// 다중 사인파를 결합하여 유기적인 수평 오로라 파동을 그리는 핵심 함수
  void _drawAuroraWave(Canvas canvas, Size size, Paint paint, 
      {required List<Color> colors, required double yOffset, required double waveHeight, required double frequency, required double speed}) {
    
    final path = Path();
    const int segments = 20; // 파동의 정교함 결정
    
    // 오로라의 그라데이션 설정 (라이브러리의 LinearGradient 효과 재현)
    paint.shader = LinearGradient(
      colors: colors,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final double phase = animationValue * 2 * math.pi * speed;

    double? prevX;
    double? prevY;

    for (int i = 0; i <= segments; i++) {
      final double progress = i / segments;
      final double x = size.width * progress;
      
      // 라이브러리 방식의 '사인파 결합' 공식: 3개의 주파수를 섞어 불규칙한 자연스러움 연출
      final wave1 = math.sin(progress * math.pi * frequency + phase) * 0.5;
      final wave2 = math.sin(progress * math.pi * (frequency + 1) + phase * 1.5) * 0.3;
      final wave3 = math.sin(progress * math.pi * (frequency + 2) + phase * 0.5) * 0.2;
      
      final double combinedWave = (wave1 + wave2 + wave3) * waveHeight;
      final double y = yOffset + combinedWave;

      if (i == 0) {
        path.moveTo(-size.width * 0.1, y);
      } else {
        // 부드러운 곡선 연결
        path.quadraticBezierTo((x + prevX!) / 2, (y + prevY!) / 2, x, y);
      }
      prevX = x;
      prevY = y;
    }

    // 오로라의 "두께"를 선의 굵기로 표현하여 흐르는 성운 효과 극대화
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.height * 0.6; // 매우 넓은 면적 커버
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.animationValue != animationValue;
}

/// 3중 Bloom 효과가 적용된 십자별 레이어
class _CustomTwinklingStars extends StatefulWidget {
  const _CustomTwinklingStars();

  @override
  State<_CustomTwinklingStars> createState() => _CustomTwinklingStarsState();
}

class _CustomTwinklingStarsState extends State<_CustomTwinklingStars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // 충분히 긴 주기로 설정
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
        return SizedBox.expand(
          child: CustomPaint(
            painter: _SparklePainter(_controller.value),
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double animationValue;
  _SparklePainter(this.animationValue);

  static final _rng = math.Random(101);
  static final List<_StarData> _stars = List.generate(
    70, 
    (_) => _StarData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: _rng.nextDouble() * 2.8 + 1.2,
      opacity: _rng.nextDouble() * 0.4 + 0.1,
      twinkleSpeed: _rng.nextDouble() * 10 + 5, // animationValue(0~1)에 곱해질 계수
      twinklePhase: _rng.nextDouble() * 2 * math.pi,
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint();
    
    for (final star in _stars) {
      // animationValue 기반 부드러운 사인파 계산
      final sinVal = math.sin((animationValue * 2 * math.pi * star.twinkleSpeed) + star.twinklePhase);
      final twinkleFactor = math.pow((sinVal + 1) / 2, 2.5); 
      final currentOpacity = (star.opacity * twinkleFactor).clamp(0.0, 1.0);
      if (currentOpacity < 0.05) continue; 

      final baseColor = (star.x > 0.6 ? SpaceColors.neonPurple : Colors.white);
      final center = Offset(star.x * size.width, star.y * size.height);
      final currentSize = star.size * (0.7 + 0.3 * twinkleFactor);

      // 3중 레이어드 Bloom 효과
      // 1. 넓은 외곽광
      paint.color = baseColor.withOpacity(currentOpacity * 0.4);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 2.5);
      _drawSparkle(canvas, center, currentSize, paint);
      
      // 2. 중간 형태광
      paint.color = baseColor.withOpacity(currentOpacity * 0.8);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 1.0);
      _drawSparkle(canvas, center, currentSize * 0.8, paint);
      
      // 3. 선명한 코어
      paint.color = baseColor.withOpacity(currentOpacity);
      paint.maskFilter = null;
      canvas.drawCircle(center, currentSize * 0.15, paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    for (int i = 0; i < 2; i++) {
      final isVertical = i == 0;
      final w = isVertical ? radius * 0.12 : radius;
      final h = isVertical ? radius : radius * 0.12;
      canvas.drawRect(Rect.fromCenter(center: center, width: w, height: h), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.animationValue != animationValue;
}

class _StarData {
  final double x, y, size, opacity, twinkleSpeed, twinklePhase;
  const _StarData({required this.x, required this.y, required this.size, required this.opacity, required this.twinkleSpeed, required this.twinklePhase});
}
