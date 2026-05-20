import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/permission/permission_health_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _homeActiveIconAssetPath = 'assets/images/home_icon_active.png';
  static const _homeInactiveIconAssetPath =
      'assets/images/home_icon_inactive.png';

  static const _tabs = [
    _TabInfo(
      activeIconAsset: _homeActiveIconAssetPath,
      inactiveIconAsset: _homeInactiveIconAssetPath,
      icon: Icons.home_filled,
      label: '홈',
    ),
    _TabInfo(icon: Icons.map_outlined, label: '지도'),
    _TabInfo(icon: Icons.list_alt_outlined, label: '할 일'),
    _TabInfo(icon: Icons.settings_outlined, label: '설정'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionBannerDismissedProvider.notifier).state = false;
      ref.invalidate(permissionHealthProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xF20F0F1A),
          border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
        ),
        padding: const EdgeInsets.only(top: 16, left: 43.77, right: 43.79),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_tabs.length, (index) {
            final isActive = widget.navigationShell.currentIndex == index;
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
    if (index != widget.navigationShell.currentIndex) {
      ref.read(permissionBannerDismissedProvider.notifier).state = false;
      ref.invalidate(permissionHealthProvider);
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
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
    final inactiveColor = const Color(0x66E9D5FF);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 37.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            info.hasImageIcon
                ? Image.asset(
                    info.resolveIconAsset(isActive),
                    width: 24,
                    height: 24,
                    color: isActive ? activeColor : inactiveColor,
                    errorBuilder: (_, __, ___) => Icon(
                      info.icon ?? Icons.home_filled,
                      color: isActive ? activeColor : inactiveColor,
                      size: 24,
                    ),
                  )
                : Icon(
                    info.icon ?? Icons.circle,
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
  const _TabInfo({
    this.icon,
    this.iconAsset,
    this.activeIconAsset,
    this.inactiveIconAsset,
    required this.label,
  });

  final IconData? icon;
  final String? iconAsset;
  final String? activeIconAsset;
  final String? inactiveIconAsset;
  final String label;

  bool get hasImageIcon =>
      iconAsset != null || activeIconAsset != null || inactiveIconAsset != null;

  String resolveIconAsset(bool isActive) {
    if (isActive) {
      return activeIconAsset ?? iconAsset ?? '';
    }

    return inactiveIconAsset ?? iconAsset ?? '';
  }
}
