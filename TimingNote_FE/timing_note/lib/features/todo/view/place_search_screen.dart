import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/location_permission_service.dart';
import '../../mypage/model/user_place.dart';
import '../../mypage/service/user_place_service.dart';
import '../model/selected_kakao_place.dart';
import '../service/place_search_service.dart';

// ── 디자인 상수 (우주 테마 통일) ─────────────────────────────────────
const _kBgDark = Color(0xFF050510);
const _kSurface = Color(0xE50F0F1A);
const _kBorderWhite = Color(0x1AFFFFFF);
const _kPurpleAccent = Color(0xFFA78BFA);
const _kPinkAccent = Color(0xFFF472B6);

// 서울 시청 (기본 초기 위치)
const _kDefaultLat = 37.5665;
const _kDefaultLng = 126.9780;

/// 장소 검색 + 카카오 지도 선택 화면.
///
/// 진입: context.push<SelectedPlace>('/place-search?keyword=이전장소명')
/// 반환: context.pop(SelectedPlace) — 카카오/지도 선택 시 SelectedExternalPlace,
///       내 장소 선택 시 SelectedAliasPlace, 취소 시 null
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, this.initialKeyword});

  final String? initialKeyword;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  KakaoMapController? _mapController;
  LatLng _center = LatLng(_kDefaultLat, _kDefaultLng);
  LatLng? _pendingPanTo; // 지도 준비 전에 위치가 먼저 오면 여기 보관
  LatLng? _lastReverseGeocoded; // 마지막으로 역지오코딩한 좌표
  String? _currentAddress;
  bool _isReverseGeocoding = false;

  // 사용자 GPS 위치 (BE setPlace의 userLatitude/userLongitude로 전달, 권한 없으면 null)
  // _center와 분리해서 저장 — _center는 핀 드래그로 바뀌지만 사용자 위치는 고정
  double? _userLatitude;
  double? _userLongitude;

  // 선택된 장소 (검색 결과 선택 시 채워짐, 지도 핀 드래그 시 null)
  KakaoPlaceItem? _selectedFromSearch;

  final _customNameController = TextEditingController();
  Timer? _rgTimer; // 역지오코딩 디바운스 타이머

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _rgTimer?.cancel();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final locationService = LocationService(LocationPermissionService());
      final pos = await locationService.getCurrentPosition();
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = latLng;
        _userLatitude = pos.latitude;
        _userLongitude = pos.longitude;
      });
      if (_mapController != null) {
        _mapController!.panTo(latLng);
      } else {
        _pendingPanTo = latLng;
      }
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      // 위치 권한 없거나 실패 시 기본 위치(서울 시청) 사용 — _userLat/Lng는 null 유지
      _reverseGeocode(_kDefaultLat, _kDefaultLng);
    }
  }

  void _onCameraIdle(LatLng center, int zoomLevel) {
    _center = center;
    // 검색으로 선택된 장소가 없을 때만 핀 드래그로 간주
    if (_selectedFromSearch == null) {
      _scheduleReverseGeocode(center.latitude, center.longitude);
    }
  }

  void _scheduleReverseGeocode(double lat, double lng) {
    // 이전 역지오코딩 위치에서 30m 이내면 스킵
    if (_lastReverseGeocoded != null) {
      final dlat = (lat - _lastReverseGeocoded!.latitude).abs();
      final dlng = (lng - _lastReverseGeocoded!.longitude).abs();
      if (dlat < 0.00027 && dlng < 0.00033) return; // ~30m
    }
    _rgTimer?.cancel();
    _rgTimer = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(lat, lng);
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isReverseGeocoding = true);
    try {
      final address = await ref
          .read(placeSearchServiceProvider)
          .reverseGeocode(lat, lng);
      if (!mounted) return;
      _lastReverseGeocoded = LatLng(lat, lng);
      setState(() {
        _currentAddress = address ?? '주소를 가져올 수 없습니다';
        _isReverseGeocoding = false;
        if (_customNameController.text.isEmpty) {
          _customNameController.text = address ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  // 검색 결과에서 장소 선택
  void _onSearchResultSelected(KakaoPlaceItem item) {
    final latLng = LatLng(item.latitude, item.longitude);
    setState(() {
      _selectedFromSearch = item;
      _center = latLng;
      _currentAddress = item.roadAddressName ?? item.addressName;
      _customNameController.text = item.placeName;
    });
    _mapController?.panTo(latLng);
  }

  // 사용자가 지도 핀을 직접 드래그할 때 검색 선택 초기화
  void _onCameraMoveStart() {
    if (_selectedFromSearch != null) {
      setState(() => _selectedFromSearch = null);
    }
  }

  void _save() {
    final name = _customNameController.text.trim();
    if (name.isEmpty) return;

    SelectedExternalPlace result;

    if (_selectedFromSearch != null) {
      // 카카오 키워드 검색 결과: kakaoPlaceId 있음
      result = _selectedFromSearch!.toSelectedPlace(
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );
    } else {
      // 지도 핀 직접 선택: kakaoPlaceId 없음 (BE에서 새 Place 레코드 생성)
      result = SelectedExternalPlace(
        kakaoPlaceId: null,
        placeName: name,
        placeLatitude: _center.latitude,
        placeLongitude: _center.longitude,
        addressName: _currentAddress,
        roadAddressName: _currentAddress,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );
    }

    context.pop(result);
  }

  /// 내 장소 시트 — 사용자 등록 별칭 목록에서 선택
  Future<void> _openUserPlaceSheet() async {
    final selected = await showModalBottomSheet<UserPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserPlaceSheet(
        userPlaceService: ref.read(userPlaceServiceProvider),
      ),
    );
    if (selected == null || !mounted) return;

    context.pop(SelectedAliasPlace(
      userPlaceId: selected.id,
      aliasName: selected.aliasName,
      placeLatitude: selected.latitude,
      placeLongitude: selected.longitude,
      userLatitude: _userLatitude,
      userLongitude: _userLongitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgDark,
      body: Stack(
        children: [
          // ── 1. 카카오 지도 (전체 화면) ─────────────────────────────
          if (kIsWeb)
            Container(
              color: const Color(0xFF1A1A2E),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: Colors.white24, size: 56),
                    SizedBox(height: 12),
                    Text('지도 미리보기는 모바일 앱에서 확인 가능합니다', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            KakaoMap(
              onMapCreated: (controller) {
                _mapController = controller;
                if (_pendingPanTo != null) {
                  controller.panTo(_pendingPanTo!);
                  _pendingPanTo = null;
                }
              },
              center: _center,
              currentLevel: 4,
              onCameraIdle: _onCameraIdle,
              onDragChangeCallback: (latLng, zoomLevel, dragType) {
                if (dragType == DragType.start) _onCameraMoveStart();
              },
            ),

          // ── 2. 중앙 핀 오버레이 ────────────────────────────────────
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: _kPinkAccent, size: 44),
                SizedBox(height: 2),
                _PinShadow(),
              ],
            ),
          ),

          // ── 3. SafeArea 콘텐츠 ─────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // 상단 바
                _TopBar(
                  onBack: () => context.pop(),
                  onSearchTap: () => _openSearchSheet(),
                  onUserPlaceTap: () => _openUserPlaceSheet(),
                ),
                const Spacer(),
                // 하단 패널
                _BottomPanel(
                  address: _currentAddress,
                  isLoading: _isReverseGeocoding,
                  nameController: _customNameController,
                  onSave: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSearchSheet() {
    showModalBottomSheet<KakaoPlaceItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        initialKeyword: widget.initialKeyword ?? _selectedFromSearch?.placeName ?? '',
        currentLat: _center.latitude,
        currentLng: _center.longitude,
        placeSearchService: ref.read(placeSearchServiceProvider),
      ),
    ).then((item) {
      if (item != null) _onSearchResultSelected(item);
    });
  }
}

// ── 상단 바 ───────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onSearchTap,
    required this.onUserPlaceTap,
  });

  final VoidCallback onBack;
  final VoidCallback onSearchTap;
  final VoidCallback onUserPlaceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // 뒤로가기
          _GlassButton(
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          // 검색바 (탭 → 검색 시트)
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderWhite),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.white38, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '주소, 장소, 상호명 검색',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 내 장소 버튼 — 사용자 등록 별칭 목록에서 선택
          _GlassButton(
            child: const Text('내 장소', style: TextStyle(color: _kPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            onTap: onUserPlaceTap,
          ),
        ],
      ),
    );
  }
}

// ── 하단 패널 (주소 + 커스텀 이름 + 저장 버튼) ────────────────────────
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.address,
    required this.isLoading,
    required this.nameController,
    required this.onSave,
  });

  final String? address;
  final bool isLoading;
  final TextEditingController nameController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: _kBorderWhite)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주소
          Row(
            children: [
              const Icon(Icons.location_on, color: _kPinkAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: isLoading
                    ? const SizedBox(
                        height: 14,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white10,
                          color: _kPurpleAccent,
                        ),
                      )
                    : Text(
                        address ?? '위치를 이동하여 주소를 확인하세요',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 커스텀 이름 입력
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorderWhite),
            ),
            child: TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: '저장할 장소 이름',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 저장 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: _kPinkAccent.withOpacity(0.4),
              ),
              onPressed: onSave,
              child: const Text(
                '이 위치 저장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 검색 시트 ─────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.initialKeyword,
    required this.currentLat,
    required this.currentLng,
    required this.placeSearchService,
  });

  final String initialKeyword;
  final double currentLat;
  final double currentLng;
  final PlaceSearchService placeSearchService;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

const _kRecentSearchesKey = 'place_recent_searches';
const _kMaxRecentSearches = 8;

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _controller;
  List<KakaoPlaceItem> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _sortByDistance = true;
  Timer? _debounce;
  // 세션 내 검색 결과 캐시 (key: "query|sortByDistance")
  final Map<String, List<KakaoPlaceItem>> _cache = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
    _loadRecentSearches().then((_) {
      if (widget.initialKeyword.isNotEmpty) _doSearch(widget.initialKeyword);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kRecentSearchesKey) ?? [];
    if (mounted) setState(() => _recentSearches = saved);
  }

  Future<void> _addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final updated = [trimmed, ..._recentSearches.where((s) => s != trimmed)]
        .take(_kMaxRecentSearches)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _removeRecentSearch(String query) async {
    final updated = _recentSearches.where((s) => s != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(value));
  }

  Future<void> _doSearch(String query) async {
    if (!mounted || query.trim().isEmpty) return;
    final cacheKey = '${query.trim()}|$_sortByDistance';
    if (_cache.containsKey(cacheKey)) {
      setState(() => _results = _cache[cacheKey]!);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final items = await widget.placeSearchService.searchKeyword(
        query,
        lat: _sortByDistance ? widget.currentLat : null,
        lng: _sortByDistance ? widget.currentLng : null,
      );
      if (!mounted) return;
      _cache[cacheKey] = items;
      setState(() {
        _results = items;
        _isSearching = false;
      });
      await _addRecentSearch(query);
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _select(KakaoPlaceItem item) => Navigator.pop(context, item);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: _kBgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 핸들
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // 검색바 행
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorderWhite),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: '주소, 장소, 상호명 검색',
                              hintStyle: TextStyle(color: Colors.white24),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 13),
                            ),
                            onChanged: _onChanged,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _doSearch,
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                              setState(() => _results = []);
                            },
                            child: const Icon(Icons.close, color: Colors.white38, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 결과 or 빈 상태
          Expanded(
            child: _results.isEmpty && !_isSearching
                ? _buildEmptyState()
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 최근 검색
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최근 검색', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: _clearRecentSearches,
                  child: const Text('전체 삭제', style: TextStyle(color: Colors.white30, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches
                  .map((kw) => GestureDetector(
                        onTap: () {
                          _controller.text = kw;
                          _doSearch(kw);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kBorderWhite),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(kw, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeRecentSearch(kw),
                                child: const Icon(Icons.close, size: 14, color: Colors.white30),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
          ],
          // 예시 힌트
          const Text(
            '주소, 장소명, 상호명으로 검색하세요',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            '예: "강남역", "스타벅스 역삼", "서울시 강남구"',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // 정렬 칩
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Row(
              children: [
                _SortChip(label: '거리순', selected: _sortByDistance, onTap: () {
                  setState(() => _sortByDistance = true);
                  _doSearch(_controller.text);
                }),
                const SizedBox(width: 8),
                _SortChip(label: '정확도순', selected: !_sortByDistance, onTap: () {
                  setState(() => _sortByDistance = false);
                  _doSearch(_controller.text);
                }),
              ],
            ),
          ),

        // 로딩
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              backgroundColor: Colors.white10,
              color: _kPurpleAccent,
              minHeight: 2,
            ),
          ),

        // 결과 리스트
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorderWhite, indent: 60),
            itemBuilder: (_, i) => _ResultTile(item: _results[i], onTap: () => _select(_results[i])),
          ),
        ),
      ],
    );
  }
}

// ── 검색 결과 타일 ────────────────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.onTap});

  final KakaoPlaceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kPinkAccent.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on, color: _kPinkAccent, size: 18),
      ),
      title: Text(
        item.placeName,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: item.roadAddressName != null
          ? Text(
              item.roadAddressName!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            )
          : null,
      trailing: item.distance != null
          ? Text(
              item.displayDistance,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            )
          : null,
    );
  }
}

// ── 정렬 칩 ───────────────────────────────────────────────────────────
class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kPinkAccent : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kPinkAccent : _kBorderWhite),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── 유리형 버튼 ───────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorderWhite),
        ),
        child: child,
      ),
    );
  }
}

// ── 핀 그림자 ─────────────────────────────────────────────────────────
class _PinShadow extends StatelessWidget {
  const _PinShadow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── 내 장소 시트 ──────────────────────────────────────────────────────
/// 사용자가 등록한 별칭 장소 목록에서 선택.
/// 항목 탭 시 Navigator.pop(UserPlace) — 취소 시 null.
class _UserPlaceSheet extends StatefulWidget {
  const _UserPlaceSheet({required this.userPlaceService});

  final UserPlaceService userPlaceService;

  @override
  State<_UserPlaceSheet> createState() => _UserPlaceSheetState();
}

class _UserPlaceSheetState extends State<_UserPlaceSheet> {
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
