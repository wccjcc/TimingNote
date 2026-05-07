import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timing_note/features/mypage/model/user_place.dart';
import 'package:timing_note/features/mypage/model/user_settings.dart';
import 'package:timing_note/features/mypage/service/user_place_service.dart';
import 'package:timing_note/features/mypage/service/user_settings_service.dart';
import 'package:timing_note/shared/theme/colors.dart';
import 'package:timing_note/shared/theme/typography.dart';
import 'package:timing_note/shared/widgets/cosmic_background.dart';
import 'package:timing_note/shared/widgets/space_card.dart';
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
      final settings = await ref.read(userSettingsServiceProvider).getSettings();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 값을 불러오지 못했습니다. 기본값으로 표시합니다.')),
      );
    }
  }

  Future<void> _deletePlace(int userPlaceId) async {
    await ref.read(userPlaceServiceProvider).deleteUserPlace(userPlaceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('장소가 삭제되었습니다.')),
    );
    await _refreshPlaces();
  }

  Future<void> _toggleLocationAlert() async {
    final nextValue = !_locationAlertEnabled;
    setState(() => _locationAlertEnabled = nextValue);
    try {
      final updated = await ref.read(userSettingsServiceProvider).updateSettings(
            locationAlertEnabled: nextValue,
          );
      if (!mounted) return;
      setState(() {
        _locationAlertEnabled = updated.locationAlertEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationAlertEnabled = !nextValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 알림 설정 저장에 실패했습니다.')),
      );
    }
  }

  Future<void> _togglePushAlert() async {
    final nextValue = !_pushAlertEnabled;
    setState(() => _pushAlertEnabled = nextValue);
    try {
      final updated = await ref.read(userSettingsServiceProvider).updateSettings(
            pushAlertEnabled: nextValue,
          );
      if (!mounted) return;
      setState(() {
        _pushAlertEnabled = updated.pushAlertEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pushAlertEnabled = !nextValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('푸시 알림 설정 저장에 실패했습니다.')),
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
      final updated = await ref.read(userSettingsServiceProvider).updateSettings(
            radiusM: newRadius,
          );
      if (!mounted) return;
      setState(() {
        _radiusMeter = updated.radiusM.toDouble();
        _savedRadiusMeter = updated.radiusM;
        _isSavingRadius = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _radiusMeter = _savedRadiusMeter.toDouble();
        _isSavingRadius = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반경 저장에 실패했습니다. 다시 시도해 주세요.')),
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
            badgeColor:
                _locationAlertEnabled ? SpaceColors.neonPurple : Colors.grey,
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
                inactiveTrackColor:
                    SpaceColors.neonPurple.withValues(alpha: 0.15),
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
      trailing: IconButton(
        onPressed: _refreshPlaces,
        icon:
            const Icon(Icons.refresh, color: SpaceColors.neonLavender, size: 18),
        tooltip: '새로고침',
      ),
      child: FutureBuilder<List<UserPlace>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('내 장소를 불러오지 못했습니다.'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _refreshPlaces, child: const Text('다시 시도')),
                ],
              ),
            );
          }

          final places = snapshot.data ?? const <UserPlace>[];
          return Column(
            children: [
              if (places.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('등록된 장소가 없습니다.'),
                )
              else
                ...List.generate(places.length, (index) {
                  final place = places[index];
                  return Column(
                    children: [
                      _PlaceTile(
                        title: place.aliasName,
                        subtitle: place.displayAddress,
                        icon:
                            index == 0 ? Icons.home_outlined : Icons.place_outlined,
                        iconColor: index == 0
                            ? SpaceColors.neonLavender
                            : SpaceColors.neonViolet,
                        onMoreTap: () => _showPlaceMenu(place),
                      ),
                      if (index != places.length - 1)
                        const Divider(height: 1, color: Color(0x22A78BFA)),
                    ],
                  );
                }),
              const Divider(height: 1, color: Color(0x22A78BFA)),
              const _AddPlaceTile(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPlaceMenu(UserPlace place) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpaceColors.space900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.edit, color: SpaceColors.neonLavender),
                title: const Text('별칭 수정'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('장소 삭제'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (result == 'delete') {
      await _deletePlace(place.id);
    }
    if (result == 'edit') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별칭 수정 API 연결은 다음 단계에서 진행합니다.')),
      );
    }
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
        SpaceCard(
          padding: EdgeInsets.zero,
          child: child,
        ),
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

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onMoreTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SpaceColors.space800,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SpaceColors.neonLavender.withValues(alpha: 0.45),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoreTap,
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: SpaceColors.neonLavender.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPlaceTile extends StatelessWidget {
  const _AddPlaceTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소 추가 API 연결은 다음 단계에서 진행합니다.')),
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            _AddCircle(),
            SizedBox(width: 12),
            Text(
              '새 장소 등록',
              style: TextStyle(
                fontFamily: SpaceTypography.pixelFontFamily,
                color: SpaceColors.neonLavender,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCircle extends StatelessWidget {
  const _AddCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SpaceColors.neonLavender.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.add, size: 18, color: SpaceColors.neonLavender),
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
  const _VersionTile({
    required this.label,
    required this.value,
  });

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
