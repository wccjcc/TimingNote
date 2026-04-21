import 'package:flutter/material.dart';

/// 실제 홈 화면 구성 전까지 사용하는 최소 스캐폴드입니다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SizedBox.expand(),
      ),
    );
  }
}
