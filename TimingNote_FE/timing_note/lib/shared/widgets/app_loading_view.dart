import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

class AppLoadingView extends StatefulWidget {
  const AppLoadingView({
    super.key,
    this.message = '데이터를 불러오는 중...',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = widget.compact ? 72.0 : 112.0;
    final fontSize = widget.compact ? 12.0 : 13.0;
    final floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    final glowAnimation = Tween<double>(begin: 0.18, end: 0.32).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, floatAnimation.value),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: imageSize * 0.84,
                    height: imageSize * 0.84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpaceColors.neonPurple.withOpacity(
                        glowAnimation.value * 0.32,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SpaceColors.neonPurple.withOpacity(
                            glowAnimation.value,
                          ),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  child!,
                ],
              ),
            );
          },
          child: Image.asset(
            'assets/images/loading.png',
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.message,
          style: TextStyle(
            fontFamily: SpaceTypography.pixelFontFamily,
            color: SpaceColors.neonLavender.withOpacity(0.9),
            fontSize: fontSize,
            letterSpacing: 0.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (widget.compact) return Center(child: content);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }
}
