import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/floating_star_tag.dart';
import '../../../../shared/widgets/space_toast.dart';
import '../widgets/home_recommend_section.dart';
import '../viewmodel/home_recommendation_viewmodel.dart';
import '../../mypage/model/user_place.dart';
import '../../mypage/service/user_place_service.dart';
import '../../notification/viewmodel/notification_viewmodel.dart';
import '../../todo/model/todo.dart';
import '../../todo/viewmodel/todo_input_viewmodel.dart';

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
    return [
      _TagSlot(left: 75, top: 20, small: false),
      _TagSlot(left: width - 75, top: 20, small: false),
      _TagSlot(left: 60, top: 140, small: true),
      _TagSlot(left: width / 2, top: 140, small: false),
      _TagSlot(left: width - 60, top: 140, small: true),
      _TagSlot(left: 110, top: 260, small: true),
      _TagSlot(left: width - 110, top: 260, small: true),
    ];
  }

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
      
      SpaceToast.show(
        context,
        message: '할 일이 등록되었습니다.',
        kind: ToastKind.success,
      );

      context.go('/todos');
      
      ref.read(todoInputProvider.notifier).reset();
    }
    if (next.phase == InputSubmitPhase.error) {
      SpaceToast.show(
        context,
        message: next.error ?? '등록 중 오류가 발생했어요',
        kind: ToastKind.error,
      );
      ref.read(todoInputProvider.notifier).resetError();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TodoInputState>(todoInputProvider, _onStateChanged);
    final inputState = ref.watch(todoInputProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );
    final recommendationState = ref.watch(homeRecommendationProvider);
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
                      SliverToBoxAdapter(
                        child: HomeRecommendSection(
                          currentLocationLabel: recommendationState.currentLocationLabel,
                          items: recommendationState.items,
                          isLoading: recommendationState.isLoading,
                          errorMessage: recommendationState.error,
                          currentLatitude: recommendationState.currentLatitude,
                          currentLongitude: recommendationState.currentLongitude,
                          onCompleteTodo: (todoId) => ref
                              .read(homeRecommendationProvider.notifier)
                              .completeTodo(todoId),
                          onRefresh: () => ref
                              .read(homeRecommendationProvider.notifier)
                              .load(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ),
            ),

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
                        child: Container(color: Colors.black.withValues(alpha: 0.5 * value)),
                      );
                    },
                  ),
                ),
              ),

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

  static const int _kMaxPlaceTags = 5;
  static const _placeColor = Color(0xFFFCD34D);
  static const _timeColor = SpaceColors.neonPurple;

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
  final double left;
  final double top;
  final bool small;
  const _TagSlot({required this.left, required this.top, this.small = false});
}

class _TagDisplay {
  final String label;
  final Color color;
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
      Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: SpaceColors.neonPink, shape: BoxShape.circle, border: Border.all(color: SpaceColors.space950, width: 2), boxShadow: [BoxShadow(color: SpaceColors.neonPink.withValues(alpha: 0.8), blurRadius: 8)]), constraints: const BoxConstraints(minWidth: 20, minHeight: 20), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
    ]),
  );
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
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        if (showActionMenu)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActionMenu(onSelectType: onSelectType),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceColors.space900.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SpaceColors.neonPurple.withValues(alpha: 0.2), width: 2),
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
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    child: Text(
                                      selectedUserPlace!.aliasName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                  backgroundColor: SpaceColors.neonPurple.withValues(alpha: 0.3),
                                  side: BorderSide(color: SpaceColors.neonPurple.withValues(alpha: 0.6)),
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
                _IconButton(
                  icon: Icons.arrow_upward,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            color: SpaceColors.space900.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SpaceColors.neonPurple.withValues(alpha: 0.3)),
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
  Widget build(BuildContext context) => ListTile(
    visualDensity: VisualDensity.compact,
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0x33A78BFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    onTap: onTap,
  );
}
