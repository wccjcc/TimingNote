import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

/// 지도 화면 우측 하단에 떠 있는 '내 위치' 버튼 위젯입니다.
/// 공용 위젯으로 분리하여 모든 지도 관련 페이지에서 일관된 UX를 제공합니다.
class MyLocationFab extends StatelessWidget {
  const MyLocationFab({super.key, required this.gps, required this.onTap});

  /// 사용자 GPS 데이터 (GpsSnapshot?). null이면 권한 없음/비활성 상태로 간주하여 회색 처리합니다.
  final Object? gps;

  /// 버튼 클릭 시 콜백. 보통 지도를 내 위치로 이동(panTo)시키는 로직을 넣습니다.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = gps != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: SpaceColors.space900,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? SpaceColors.neonPurple.withOpacity(0.6)
                  : SpaceColors.white10,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: SpaceColors.neonPurple.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.my_location,
            color: enabled ? SpaceColors.neonPurple : SpaceColors.white20,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// 위치 권한이 없거나 꺼져 있을 때 보여주는 안내 바텀 시트를 띄웁니다.
  static void showLocationUnavailableSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetContext) {
        return _LocationUnavailableSheet(
          onOpenSettings: () {
            Navigator.of(sheetContext).pop();
            context.go('/my');
          },
          onClose: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
  }
}

class _LocationUnavailableSheet extends StatelessWidget {
  const _LocationUnavailableSheet({
    required this.onOpenSettings,
    required this.onClose,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: SpaceColors.space900,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: SpaceColors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SpaceColors.neonPurple.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: SpaceColors.neonPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '현재 위치를 사용할 수 없어요',
                      style: TextStyle(
                        color: SpaceColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '지도와 장소 검색은 계속 사용할 수 있지만, 위치 권한과 기기 위치가 꺼져 있으면 주변 후보와 도착 알림이 제한돼요.',
                style: TextStyle(
                  color: SpaceColors.white.withOpacity(0.62),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onClose,
                      child: const Text(
                        '그대로 보기',
                        style: TextStyle(color: SpaceColors.white50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onOpenSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpaceColors.neonPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('권한 확인'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
