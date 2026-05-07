import 'package:flutter/material.dart';

import '../../mypage/model/user_place.dart';
import '../../mypage/service/user_place_service.dart';

const _kBgDark = Color(0xFF050510);
const _kBorderWhite = Color(0x1AFFFFFF);
const _kPurpleAccent = Color(0xFFA78BFA);

/// 사용자가 등록한 별칭 장소 목록 모달.
/// 항목 탭 시 Navigator.pop(UserPlace) — 취소 시 null.
///
/// 사용처:
/// - place_search_screen "내 장소" 버튼
/// - todo_input_screen 등록 시 ALIAS 명시 선택
class UserPlaceSheet extends StatefulWidget {
  const UserPlaceSheet({super.key, required this.userPlaceService});

  final UserPlaceService userPlaceService;

  @override
  State<UserPlaceSheet> createState() => _UserPlaceSheetState();
}

class _UserPlaceSheetState extends State<UserPlaceSheet> {
  List<UserPlace>? _places;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.userPlaceService.getUserPlaces();
      if (!mounted) return;
      setState(() => _places = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: _kBgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.bookmark, color: _kPurpleAccent, size: 18),
                SizedBox(width: 8),
                Text('내 장소', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '내 장소를 불러오지 못했습니다.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      );
    }
    if (_places == null) {
      return const Center(child: CircularProgressIndicator(color: _kPurpleAccent));
    }
    if (_places!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '등록된 내 장소가 없습니다.\n마이페이지에서 자주 가는 장소를 등록해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _places!.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorderWhite, indent: 60),
      itemBuilder: (_, i) {
        final place = _places![i];
        return ListTile(
          onTap: () => Navigator.pop(context, place),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kPurpleAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bookmark, color: _kPurpleAccent, size: 18),
          ),
          title: Text(
            place.aliasName,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            place.displayAddress,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
