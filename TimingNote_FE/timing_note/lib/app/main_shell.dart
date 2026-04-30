import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // 탭 구성
  static const _tabs = [
    _TabInfo(icon: Icons.home_filled, label: '홈'),
    _TabInfo(icon: Icons.map_outlined, label: '지도'),
    _TabInfo(icon: Icons.list_alt_outlined, label: '할 일'),
    _TabInfo(icon: Icons.settings_outlined, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 하단바와 본문이 겹치도록 설정 (배경 투명도 효과를 위해)
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xF20F0F1A), // rgba(15, 15, 26, 0.95)
          border: Border(
            top: BorderSide(color: Color(0x1AFFFFFF), width: 1), // White 10%
          ),
        ),
        padding: const EdgeInsets.only(top: 16, left: 43.77, right: 43.79),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_tabs.length, (index) {
            final isActive = navigationShell.currentIndex == index;
            return _BottomNavItem(
              info: _tabs[index],
              isActive: isActive,
              onTap: () => _onTap(index),
            );
          }),
        ),
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.info,
    required this.isActive,
    required this.onTap,
  });

  final _TabInfo info;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFA78BFA);
    final inactiveColor = const Color(0x66E9D5FF); // rgba(233, 213, 255, 0.4)

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 37.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              info.icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              info.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabInfo {
  const _TabInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
