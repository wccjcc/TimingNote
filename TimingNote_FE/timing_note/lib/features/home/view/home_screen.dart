import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/floating_star_tag.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../widgets/home_recommend_section.dart';
import '../../mypage/model/user_place.dart';
import '../../mypage/service/user_place_service.dart';
import '../../notification/viewmodel/notification_viewmodel.dart';
import '../../todo/model/todo.dart';
import '../../todo/viewmodel/todo_input_viewmodel.dart';
import '../../todo/viewmodel/todo_list_viewmodel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String _inputType = InputType.text;
  bool _showActionMenu = false;
  bool _isInputMode = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isInputMode = true);
      }
    });
  }

  /// 별자리 패턴 슬롯 (7개, 2-3-2 행 구성):
  ///   행 1 (top 20):  좌중, 우중              [큰 큰]
  ///   행 2 (top 140): 좌끝, 중앙, 우끝         [작 큰 작]
  ///   행 3 (top 260): 좌중, 우중              [작 작]
  /// 중앙 별은 화면 폭에 따라 동적 계산 → 디바이스 회전/크기 자동 대응.
  List<_TagSlot> _buildConstellationSlots(double width) {
    // FloatingStarTag는 자체적으로 FractionalTranslation(-0.5,0)을 적용 → Positioned.left가
    // 가리키는 X가 paint 중심(별 중심)이 된다.
    // 주의: FractionalTranslation은 paint만 이동시키므로 Positioned.right는 라벨 폭에 의존해
    // 중심이 어긋난다 → 슬롯은 모두 left로만 정의한다.
    return [
      // 행 1: 좌/우 큰 별
      _TagSlot(left: 75, top: 20, small: false),
      _TagSlot(left: width - 75, top: 20, small: false),
      // 행 2: 좌끝(작) + 중앙(큰) + 우끝(작)
      _TagSlot(left: 60, top: 140, small: true),
      _TagSlot(left: width / 2, top: 140, small: false),
      _TagSlot(left: width - 60, top: 140, small: true),
      // 행 3: 좌중 + 우중 (작)
      _TagSlot(left: 110, top: 260, small: true),
      _TagSlot(left: width - 110, top: 260, small: true),
    ];
  }

  /// 현재 시각 기반 시간 태그 추천. 발표 후 사용자 맞춤 통계로 진화 예정.
  List<String> _suggestTimeTags() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return const ['오늘 점심', '오늘 저녁', '내일 오전', '매주 월요일', '이번 주말', '오늘 퇴근 후', '이번 주 안에'];
    } else if (hour < 18) {
      return const ['오늘 저녁', '내일 오전', '내일 오후 3시', '매주 월요일', '이번 주말', '오늘 퇴근 후', '이번 주 안에'];
    } else {
      return const ['내일 오전', '내일 오후 3시', '내일 저녁', '매주 월요일', '이번 주말', '내일 퇴근 후', '이번 주 안에'];
    }
  }

  /// 별 태그 클릭 분기:
  /// - 장소(_TagDisplay.place != null) → state.selectedUserPlace 설정 (입력창 prefix chip으로 고정)
  /// - 시간 → 입력창 커서 위치에 텍스트 삽입
  void _onTagTap(_TagDisplay tag) {
    if (tag.place != null) {
      ref.read(todoInputProvider.notifier).setUserPlace(tag.place!);
      return;
    }
    _insertTextAtCursor(tag.label);
  }

  void _insertTextAtCursor(String tag) {
    final currentText = _textController.text;
    final selection = _textController.selection;
    final insertStart = selection.isValid ? selection.start : currentText.length;
    final insertEnd = selection.isValid ? selection.end : currentText.length;

    final before = currentText.substring(0, insertStart);
    final needsLeadingSpace = before.isNotEmpty && !before.endsWith(' ');
    final inserted = '${needsLeadingSpace ? ' ' : ''}$tag ';

    final newText = currentText.replaceRange(insertStart, insertEnd, inserted);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertStart + inserted.length),
    );
    _onTextChanged(newText);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    ref.read(todoInputProvider.notifier).setContent(value);
  }

  void _onSelectType(String type) {
    setState(() {
      _inputType = type;
      _showActionMenu = false;
    });
    ref.read(todoInputProvider.notifier).setInputType(type);
  }

  void _onSubmit() {
    if (_textController.text.trim().isEmpty) return;
    _focusNode.unfocus();
    ref.read(todoInputProvider.notifier).submit();
  }

  void _onStateChanged(TodoInputState? prev, TodoInputState next) {
    if (!mounted) return;
    if (next.phase == InputSubmitPhase.done && prev?.phase != InputSubmitPhase.done) {
      _textController.clear();
      setState(() {
        _inputType = InputType.text;
        _showActionMenu = false;
        _isInputMode = false;
      });
      ref.read(todoInputProvider.notifier).reset();
      ref.invalidate(todoListProvider);
    }
    if (next.phase == InputSubmitPhase.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.error ?? '등록 중 오류가 발생했어요'), backgroundColor: SpaceColors.error),
      );
      ref.read(todoInputProvider.notifier).resetError();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TodoInputState>(todoInputProvider, _onStateChanged);
    final inputState = ref.watch(todoInputProvider);
    final todoListState = ref.watch(todoListProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );
    // 내 장소: 등록/삭제 시 invalidate되어 자동 갱신됨. 로딩/에러 시 빈 목록 fallback
    final userPlaces = ref.watch(userPlacesProvider).maybeWhen(
      data: (list) => list,
      orElse: () => const <UserPlace>[],
    );
    final hasText = _textController.text.trim().isNotEmpty;

    return Scaffold(
      body: CosmicBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _HomeHeader(unreadCount: unreadCount)),
                      const SliverToBoxAdapter(
                        child: HomeRecommendSection(
                          currentLocationLabel: 'Current location',
                        ),
                      ),
                      if (todoListState.isLoading && todoListState.items.isEmpty)
                        const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: SpaceColors.neonPurple)))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final todo = todoListState.items[index];
                                return _TimelineCard(
                                  isLeft: index % 2 == 0,
                                  distance: todo.resolvedPlaceLabel ?? '어디서든 가능',
                                  title: todo.content,
                                  memo: todo.category != null ? TodoCategory.labels[todo.category] ?? '일반' : '나중에 확인',
                                  planetAsset: 'assets/images/냥냥이별1.png',
                                  onComplete: () => ref.read(todoListProvider.notifier).toggleStatus(todo.id),
                                );
                              },
                              childCount: todoListState.items.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ),
            ),

            // LAYER 2: 입력 모드 전용 오버레이 (블러 + 닫기 핸들러)
            if (_isInputMode) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _focusNode.unfocus();
                    setState(() => _isInputMode = false);
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                        child: Container(color: Colors.black.withOpacity(0.5 * value)),
                      );
                    },
                  ),
                ),
              ),

              // LAYER 3: 플로팅 태그 (블러 위에 표시)
              Positioned.fill(
                top: 50,
                bottom: 220,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _FloatingTagArea(
                      isFocused: _isInputMode,
                      places: userPlaces,
                      timeSuggestions: _suggestTimeTags(),
                      slots: _buildConstellationSlots(
                        math.min(MediaQuery.of(context).size.width, 500.0),
                      ),
                      onTagTap: _onTagTap,
                    ),
                  ),
                ),
              ),
            ],

            // LAYER 4: 하단 입력바 (항상 최상단)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _BottomInputBar(
                    controller: _textController,
                    focusNode: _focusNode,
                    inputType: _inputType,
                    isLoading: inputState.isSubmitting,
                    hasText: hasText,
                    showActionMenu: _showActionMenu,
                    isInputMode: _isInputMode,
                    selectedUserPlace: inputState.selectedUserPlace,
                    onClearPlace: () =>
                        ref.read(todoInputProvider.notifier).clearUserPlace(),
                    onTextChanged: _onTextChanged,
                    onToggleMenu: () => setState(() => _showActionMenu = !_showActionMenu),
                    onSelectType: _onSelectType,
                    onSubmit: _onSubmit,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 하위 위젯: 플로팅 태그 영역 ──────────────────────────────────────────
/// 입력창 focus 시 별처럼 떠오르는 추천 태그.
/// - 장소: 사용자 등록 내 장소 (최대 _kMaxPlaceTags개) — 노란색, 클릭 시 prefix chip으로 고정
/// - 시간: 현재 시각 기반 추천 — 보라색, 클릭 시 입력창 커서 위치에 텍스트 삽입
/// 슬롯 위치는 부모(_HomeScreenState)가 랜덤 생성한 것을 받아 사용.
class _FloatingTagArea extends StatelessWidget {
  const _FloatingTagArea({
    required this.isFocused,
    required this.onTagTap,
    required this.places,
    required this.timeSuggestions,
    required this.slots,
  });

  final bool isFocused;
  final ValueChanged<_TagDisplay> onTagTap;
  final List<UserPlace> places;
  final List<String> timeSuggestions;
  final List<_TagSlot> slots;

  // 장소 태그 개수 상한 — 별자리 행1(2) + 행2(3) = 5개 슬롯까지 등록 장소로 채운다.
  // 나머지 슬롯(행3)은 시간 태그로 채움.
  static const int _kMaxPlaceTags = 5;

  static const _placeColor = Color(0xFFFCD34D);    // 노란
  static const _timeColor = SpaceColors.neonPurple; // 보라

  @override
  Widget build(BuildContext context) {
    final placeCount = math.min(places.length, _kMaxPlaceTags);
    final timeCount = math.min(timeSuggestions.length, slots.length - placeCount);

    final tags = <_TagDisplay>[
      for (var i = 0; i < placeCount; i++)
        _TagDisplay(label: places[i].aliasName, color: _placeColor, place: places[i]),
      for (var i = 0; i < timeCount; i++)
        _TagDisplay(label: timeSuggestions[i], color: _timeColor),
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: isFocused ? 1.0 : 0.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < math.min(tags.length, slots.length); i++)
            Positioned(
              left: slots[i].left,
              top: slots[i].top,
              child: FloatingStarTag(
                label: tags[i].label,
                glowColor: tags[i].color,
                onTap: () => onTagTap(tags[i]),
                small: slots[i].small,
              ),
            ),
        ],
      ),
    );
  }
}

class _TagSlot {
  // left = 별 중심 X 좌표 (FloatingStarTag의 FractionalTranslation 기준).
  // right는 라벨 폭에 anchor가 의존해 사용하지 않는다.
  final double left;
  final double top;
  final bool small;
  const _TagSlot({required this.left, required this.top, this.small = false});
}

class _TagDisplay {
  final String label;
  final Color color;
  /// 장소 태그면 UserPlace, 시간 태그면 null.
  final UserPlace? place;
  const _TagDisplay({required this.label, required this.color, this.place});
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.unreadCount});
  final int unreadCount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('> 지금 할 수 있어요!', style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'Galmuri11', fontWeight: FontWeight.bold, shadows: [Shadow(color: Color(0x7FA78BFA), blurRadius: 10, offset: Offset(0, 4))])),
          ], 
        ),
        _NotificationBadge(
          count: unreadCount,
          onTap: () => context.push('/notifications'),
        ),
      ],
    ),
  );
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count, this.onTap});
  final int count;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xCC2A2A4A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x4CA78BFA)), boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))]), child: const Icon(Icons.notifications_none, color: Colors.white, size: 24)),
      Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: SpaceColors.neonPink, shape: BoxShape.circle, border: Border.all(color: SpaceColors.space950, width: 2), boxShadow: [BoxShadow(color: SpaceColors.neonPink.withOpacity(0.8), blurRadius: 8)]), constraints: const BoxConstraints(minWidth: 20, minHeight: 20), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
    ]),
  );
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.isLeft, required this.distance, required this.title, required this.memo, required this.planetAsset, required this.onComplete, this.opacity = 1.0});
  final bool isLeft;
  final String distance, title, memo, planetAsset;
  final VoidCallback onComplete;
  final double opacity;
  @override
  Widget build(BuildContext context) => Opacity(opacity: opacity, child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(child: isLeft ? _buildContent(context) : _buildPlanet()),
    SizedBox(width: 40, child: Stack(alignment: Alignment.center, children: [Container(width: 2, color: Colors.white.withOpacity(0.2)), Container(width: 10, height: 10, decoration: const BoxDecoration(color: SpaceColors.neonLavender, shape: BoxShape.circle))])),
    Expanded(child: isLeft ? _buildPlanet() : _buildContent(context)),
  ])));
  Widget _buildContent(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
    Text(distance, style: const TextStyle(color: SpaceColors.neonPurple, fontSize: 10, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 4),
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: isLeft ? TextAlign.right : TextAlign.left),
    const SizedBox(height: 4),
    Text(memo, style: const TextStyle(color: Color(0x99E9D5FF), fontSize: 11), textAlign: isLeft ? TextAlign.right : TextAlign.left),
    const SizedBox(height: 10),
    NeonButton(label: '완료', onTap: onComplete, height: 32, isPrimary: true),
  ]));
  Widget _buildPlanet() => Center(child: Container(width: 70, height: 70, decoration: BoxDecoration(image: DecorationImage(image: AssetImage(planetAsset), fit: BoxFit.contain))));
}

class _BottomInputBar extends StatelessWidget {
  const _BottomInputBar({
    required this.controller,
    required this.focusNode,
    required this.inputType,
    required this.isLoading,
    required this.hasText,
    required this.showActionMenu,
    required this.isInputMode,
    required this.selectedUserPlace,
    required this.onClearPlace,
    required this.onTextChanged,
    required this.onToggleMenu,
    required this.onSelectType,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String inputType;
  final bool isLoading, hasText, showActionMenu, isInputMode;
  final UserPlace? selectedUserPlace;
  final VoidCallback onClearPlace;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleMenu;
  final ValueChanged<String> onSelectType;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      // iOS 키보드가 뜨면 시스템이 자연스럽게 입력바를 밀어올림.
      // 과거 isInputMode 분기로 +120 추가 padding을 주었으나 키보드 유무와 관계없이 항상 올라가
      // 이중 리프트로 보이는 문제 → 항상 동일 padding 유지.
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + 10),
      // 외부 배경/상단 라인 제거 — 입력창 내부 둥근 박스만 시각적으로 남도록.
      // 배경은 CosmicBackground가 책임.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // 메뉴는 입력바 Row의 + 버튼 위쪽에 좌측 정렬로 띄움 (가운데 정렬 X).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        if (showActionMenu)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActionMenu(onSelectType: onSelectType),
          ),
        // 입력창 뒤 콘텐츠를 흐려서 가독성 ↑ — ActionMenu와 동일한 패턴(ClipRRect + BackdropFilter).
        // Container.decoration에도 borderRadius를 동일하게 줘야 둥근 모서리에서 border가 잘리지 않음.
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceColors.space900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.2), width: 2),
              ),
              child: Row(children: [
                _IconButton(icon: showActionMenu ? Icons.close : Icons.add, onTap: onToggleMenu),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onTextChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: selectedUserPlace != null
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InputChip(
                                  avatar: const Icon(Icons.bookmark, size: 14, color: Colors.white),
                                  // 별칭이 길어도 입력창 폭을 잠식하지 않게 maxWidth + ellipsis.
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    child: Text(
                                      selectedUserPlace!.aliasName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                  backgroundColor: SpaceColors.neonPurple.withOpacity(0.3),
                                  side: BorderSide(color: SpaceColors.neonPurple.withOpacity(0.6)),
                                  deleteIconColor: Colors.white70,
                                  onDeleted: onClearPlace,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                            : null,
                        prefixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
                        hintText: '새로운 할 일을 입력하세요',
                        hintStyle: const TextStyle(color: Color(0x66D8B4FE), fontSize: 15),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                // 음성 입력은 iOS 키보드의 받아쓰기로 위임 — 자체 마이크 버튼 미운영.
                _IconButton(
                  icon: Icons.arrow_upward,
                  // isLoading이면 onTap 자동 비활성 → 중복 전송 방지
                  onTap: (hasText && !isLoading) ? onSubmit : null,
                  isPrimary: hasText,
                  loading: isLoading,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.loading = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? SpaceColors.neonPurple : const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? SpaceColors.neonPurple : const Color(0x4CA78BFA),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, offset: Offset(0, 4)),
          ],
        ),
        // 진행 중에는 작은 스피너로 작동 중임을 명확히. iOS Activity Indicator처럼 흰색 strokeWidth 2.
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.onSelectType});
  final ValueChanged<String> onSelectType;
  @override
  Widget build(BuildContext context) {
    // 입력창과 동일한 어두움(space900 알파 0.9) + 뒤 콘텐츠를 흐리는 BackdropFilter.
    // ClipRRect와 동일한 borderRadius를 Container에도 줘야 둥근 모서리에서 border가 잘리지 않음.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            color: SpaceColors.space900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(icon: Icons.image_outlined, label: '이미지 분석', onTap: () => onSelectType(InputType.image)),
              const Divider(color: Color(0x1AFFFFFF), height: 1),
              _MenuItem(icon: Icons.link, label: '링크', onTap: () => onSelectType(InputType.link)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(visualDensity: VisualDensity.compact, leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0x33A78BFA), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)), title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)), onTap: onTap);
}
