import 'package:flutter/material.dart';

import '../widgets/home_recommend_section.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: HomeRecommendSection(),
      ),
    );
  }
}
