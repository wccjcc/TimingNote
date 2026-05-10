import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timing_note/core/geofence/geofence_runtime.dart';
import 'package:timing_note/features/mypage/model/user_place.dart';
import 'package:timing_note/features/mypage/service/user_place_service.dart';
import 'package:timing_note/features/mypage/service/user_settings_service.dart';
import 'package:timing_note/features/mypage/view/my_places_screen.dart';
import 'package:timing_note/shared/theme/colors.dart';
import 'package:timing_note/shared/theme/typography.dart';
import 'package:timing_note/shared/widgets/cosmic_background.dart';
import 'package:timing_note/shared/widgets/space_card.dart';
import 'package:timing_note/shared/widgets/space_toast.dart';
import 'package:timing_note/shared/widgets/status_badge.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  double _radiusMeter = 300;
  int _savedRadiusMeter = 300;
  bool _locationAlertEnabled = true;
  bool _pushAlertEnabled = true;

  bool _isLoadingSettings = true;
  bool _isSavingRadius = false;

  Future<List<UserPlace>> _placesFuture = Future.value(const []);

  @override
  void initState() {
    super.initState();
    _placesFuture = _loadPlaces();
    _loadSettings();
  }

  Future<List<UserPlace>> _loadPlaces() {
    return ref.read(userPlaceServiceProvider).getUserPlaces();
  }

  Future<void> _refreshPlaces() async {
    setState(() {
      _placesFuture = _loadPlaces();
    });
    await _placesFuture;
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ref
          .read(userSettingsServiceProvider)
          .getSettings();
      if (!mounted) return;

      setState(() {
        _locationAlertEnabled = settings.locationAlertEnabled;
        _pushAlertEnabled = settings.pushAlertEnabled;
        _radiusMeter = settings.radiusM.toDouble();
        _savedRadiusMeter = settings.radiusM;
        _isLoadingSettings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSettings = false;
      });
      SpaceToast.show(
        context,
        message: '설정을 불러오지 못해 기본값으로 표시했어요',
        kind: ToastKind.info,
      );
    }
  }

  Future<void> _toggleLocationAlert() async {
    final nextValue = !_locationAlertEnabled;
    setState(() => _locationAlertEnabled = nextValue);
    try {
      final updated = await ref
          .read(userSettingsServiceProvider)
          .updateSettings(locationAlertEnabled: nextValue);
      if (!mounted) return;
      setState(() {
        _locationAlertEnabled = updated.locationAlertEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationAlertEnabled = !nextValue);
      SpaceToast.show(
        context,
        message: '위치 알림 설정 저장에 실패했어요',
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _togglePushAlert() async {
    final nextValue = !_pushAlertEnabled;
    setState(() => _pushAlertEnabled = nextValue);
    try {
      final updated = await ref
          .read(userSettingsServiceProvider)
          .updateSettings(pushAlertEnabled: nextValue);
      if (!mounted) return;
      setState(() {
        _pushAlertEnabled = updated.pushAlertEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pushAlertEnabled = !nextValue);
      SpaceToast.show(
        context,
        message: '푸시 알림 설정 저장에 실패했어요',
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _saveRadiusOnChangeEnd(double value) async {
    final newRadius = value.round();
    if (newRadius == _savedRadiusMeter || _isSavingRadius) {
      return;
    }

    setState(() {
      _isSavingRadius = true;
    });

    try {
      final updated = await ref
          .read(userSettingsServiceProvider)
          .updateSettings(radiusM: newRadius);
      if (!mounted) return;
      setState(() {
        _radiusMeter = updated.radiusM.toDouble();
        _savedRadiusMeter = updated.radiusM;
        _isSavingRadius = false;
      });
      // 서버에 저장된 새 반경을 즉시 iOS/Android geofence 등록값으로 반영한다.
      // syncSlots()는 최신 slot.radiusM을 다시 받아 네이티브 감시 영역을 재등록한다.
      await ref.read(geofenceRuntimeProvider).syncSlots();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _radiusMeter = _savedRadiusMeter.toDouble();
        _isSavingRadius = false;
      });
      SpaceToast.show(
        context,
        message: '반경 저장에 실패했어요. 다시 시도해 주세요',
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceColors.space950,
      body: CosmicBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshPlaces,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildPermissionSection(),
                  const SizedBox(height: 20),
                  _buildRadiusSection(),
                  const SizedBox(height: 20),
                  _buildPlacesSection(),
                  const SizedBox(height: 20),
                  _buildSystemSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings, size: 14, color: SpaceColors.neonPurple),
            SizedBox(width: 6),
            Text(
              'SYSTEM CONFIG',
              style: TextStyle(
                fontFamily: SpaceTypography.pixelFontFamily,
                color: SpaceColors.neonPurple,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          '> 설정 화면',
          style: TextStyle(
            fontFamily: SpaceTypography.pixelFontFamily,
            color: SpaceColors.white,
            fontSize: 24,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionSection() {
    return _SettingGroup(
      title: 'Sensor Permissions',
      child: Column(
        children: [
          _PermissionTile(
            icon: Icons.location_on_outlined,
            iconColor: SpaceColors.neonPurple,
            iconBackground: const Color(0x22A78BFA),
            title: '위치 알림 상태',
            subtitle: '지오펜스 동작을 위한 위치 권한',
            badgeText: _locationAlertEnabled ? 'ONLINE' : 'OFFLINE',
            badgeColor: _locationAlertEnabled
                ? SpaceColors.neonPurple
                : Colors.grey,
            onTap: _isLoadingSettings ? null : _toggleLocationAlert,
          ),
          const Divider(height: 1, color: Color(0x22A78BFA)),
          _PermissionTile(
            icon: Icons.notifications_active_outlined,
            iconColor: SpaceColors.neonPink,
            iconBackground: const Color(0x22F472B6),
            title: '푸시 알림 상태',
            subtitle: '시스템 알림 수신 권한',
            badgeText: _pushAlertEnabled ? 'ONLINE' : 'OFFLINE',
            badgeColor: _pushAlertEnabled ? SpaceColors.neonPink : Colors.grey,
            onTap: _isLoadingSettings ? null : _togglePushAlert,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSection() {
    final radiusText = _radiusMeter >= 1000
        ? '${(_radiusMeter / 1000).toStringAsFixed(1)}km'
        : '${_radiusMeter.round()}m';

    return _SettingGroup(
      title: 'Radar Radius',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSavingRadius)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_isSavingRadius) const SizedBox(width: 8),
          Text(
            radiusText,
            style: const TextStyle(
              fontFamily: SpaceTypography.pixelFontFamily,
              color: SpaceColors.neonLavender,
              fontSize: 14,
            ),
          ),
        ],
      ),
      child: SpaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: SpaceColors.neonPurple.withValues(alpha: 0.6),
                inactiveTrackColor: SpaceColors.neonPurple.withValues(
                  alpha: 0.15,
                ),
                thumbColor: SpaceColors.neonPurple,
                overlayColor: SpaceColors.neonPurple.withValues(alpha: 0.18),
                trackHeight: 8,
              ),
              child: Slider(
                value: _radiusMeter,
                min: 100,
                max: 1000,
                divisions: 9,
                onChanged: (value) => setState(() => _radiusMeter = value),
                onChangeEnd: _saveRadiusOnChangeEnd,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RangeCaption('100m (MIN)'),
                  _RangeCaption('500m'),
                  _RangeCaption('1.0km (MAX)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesSection() {
    return _SettingGroup(
      title: 'Registered Planets',
      child: FutureBuilder<List<UserPlace>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final count = snapshot.data?.length ?? 0;
          return _MyPlacesEntryTile(
            count: count,
            isLoading: isLoading,
            onTap: _openMyPlaces,
          );
        },
      ),
    );
  }

  Future<void> _openMyPlaces() async {
    await context.push('/my/places');
    if (!mounted) return;
    // 내 장소 화면에서 추가/삭제/변경이 일어났을 수 있어 카운트 재조회
    await _refreshPlaces();
  }

  Widget _buildSystemSection() {
    return _SettingGroup(
      title: 'System Intel',
      child: Column(
        children: const [
          _SimpleActionTile(label: '앱 버전 업데이트 안내'),
          Divider(height: 1, color: Color(0x22A78BFA)),
          _VersionTile(label: '현재 앱 버전', value: 'V1.0.0-PROXIMA'),
        ],
      ),
    );
  }
}

class _SettingGroup extends StatelessWidget {
  const _SettingGroup({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '> $title',
                style: const TextStyle(
                  fontFamily: SpaceTypography.pixelFontFamily,
                  color: Color(0x80D8B4FE),
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        SpaceCard(padding: EdgeInsets.zero, child: child),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      color: SpaceColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SpaceColors.neonLavender.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(label: badgeText, color: badgeColor),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: SpaceColors.neonLavender.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeCaption extends StatelessWidget {
  const _RangeCaption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: SpaceTypography.pixelFontFamily,
        fontSize: 9,
        color: Color(0x66D8B4FE),
      ),
    );
  }
}

class _MyPlacesEntryTile extends StatelessWidget {
  const _MyPlacesEntryTile({
    required this.count,
    required this.isLoading,
    required this.onTap,
  });

  final int count;
  final bool isLoading;
  final VoidCallback onTap;

  Color _badgeColor() {
    if (count >= kMyPlacesLimit) return SpaceColors.error;
    if (count >= kMyPlacesLimit - 2) return SpaceColors.neonYellow;
    return SpaceColors.neonLavender;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SpaceColors.space800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SpaceColors.neonLavender.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.place_outlined,
                color: SpaceColors.neonLavender,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 장소 관리',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      color: SpaceColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '자주 가는 곳을 별칭으로 등록해요',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SpaceColors.neonLavender.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!isLoading)
              StatusBadge(
                label: '$count / $kMyPlacesLimit',
                color: _badgeColor(),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: SpaceColors.neonLavender.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleActionTile extends StatelessWidget {
  const _SimpleActionTile({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13,
                  color: SpaceColors.neonLavender,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: SpaceColors.neonLavender.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13,
                color: SpaceColors.neonLavender,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: SpaceTypography.pixelFontFamily,
              fontSize: 12,
              color: SpaceColors.neonPink,
            ),
          ),
        ],
      ),
    );
  }
}
