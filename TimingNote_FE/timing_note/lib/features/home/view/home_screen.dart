import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/cosmic_background.dart';
import '../../../../shared/widgets/floating_star_tag.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../../shared/widgets/space_card.dart';
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
                      const SliverToBoxAdapter(child: _HomeHeader()),
                      if (todoListState.isLoading && todoListState.items.isEmpty)
                        const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: SpaceColors.neonPurple)))
                      else if (todoListState.items.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: Text('아직 등록된 할 일이 없어요.\n아래에서 첫 번째 기록을 남겨보세요!', textAlign: TextAlign.center, style: TextStyle(color: SpaceColors.white50, height: 1.5))),
                        )
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
                      onTagTap: (tag) {
                        final currentText = _textController.text;
                        final separator = (currentText.isEmpty || currentText.endsWith(' ')) ? '' : ' ';
                        _textController.text = '$currentText$separator$tag';
                        _onTextChanged(_textController.text);
                      },
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
class _FloatingTagArea extends StatelessWidget {
  const _FloatingTagArea({required this.isFocused, required this.onTagTap});
  final bool isFocused;
  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: isFocused ? 1.0 : 0.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAnimatedTag(left: 30, top: 40, label: '스타벅스 강남점', color: const Color(0xFFFCD34D)),
          _buildAnimatedTag(right: 40, top: 120, label: '내일 오후 3시', color: const Color(0xFFFDBA74)),
          _buildAnimatedTag(left: 80, top: 220, label: '매주 월요일', color: const Color(0xFFFCD34D), small: true),
          _buildAnimatedTag(right: 20, top: 280, label: '다이소', color: const Color(0xFFFDBA74), small: true),
          _buildAnimatedTag(left: 160, top: 20, label: '오늘 저녁', color: SpaceColors.neonPurple, small: true),
        ],
      ),
    );
  }

  Widget _buildAnimatedTag({double? left, double? top, double? right, double? bottom, required String label, required Color color, bool small = false}) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: FloatingStarTag(
        label: label,
        glowColor: color,
        onTap: () => onTagTap(label),
        small: small,
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.location_on, color: SpaceColors.neonPurple, size: 14), const SizedBox(width: 4), Text('현재 위치: 광주 상무지구', style: TextStyle(color: SpaceColors.neonPurple.withOpacity(0.8), fontSize: 11))]),
            const SizedBox(height: 8),
            const Text('> 지금 할 수 있어요!', style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'Galmuri11', fontWeight: FontWeight.bold, shadows: [Shadow(color: Color(0x7FA78BFA), blurRadius: 10, offset: Offset(0, 4))])),
          ],
        ),
        const _NotificationBadge(count: 2),
      ],
    ),
  );
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xCC2A2A4A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x4CA78BFA)), boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))]), child: const Icon(Icons.notifications_none, color: Colors.white, size: 24)),
    Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: SpaceColors.neonPink, shape: BoxShape.circle, border: Border.all(color: SpaceColors.space950, width: 2), boxShadow: [BoxShadow(color: SpaceColors.neonPink.withOpacity(0.8), blurRadius: 8)]), constraints: const BoxConstraints(minWidth: 20, minHeight: 20), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
  ]);
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
  const _BottomInputBar({required this.controller, required this.focusNode, required this.inputType, required this.isLoading, required this.hasText, required this.showActionMenu, required this.isInputMode, required this.onTextChanged, required this.onToggleMenu, required this.onSelectType, required this.onSubmit});
  final TextEditingController controller;
  final FocusNode focusNode;
  final String inputType;
  final bool isLoading, hasText, showActionMenu, isInputMode;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleMenu;
  final ValueChanged<String> onSelectType;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + (isInputMode ? 120 : 10)), decoration: const BoxDecoration(color: SpaceColors.space900, border: Border(top: BorderSide(color: SpaceColors.white10))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (showActionMenu) Padding(padding: const EdgeInsets.only(bottom: 8), child: _ActionMenu(onSelectType: onSelectType)),
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: SpaceColors.space900.withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.2), width: 2)), child: Row(children: [
        _IconButton(icon: showActionMenu ? Icons.close : Icons.add, onTap: onToggleMenu),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: controller, focusNode: focusNode, onChanged: onTextChanged, style: const TextStyle(color: Colors.white, fontSize: 15), decoration: const InputDecoration(hintText: '새로운 할 일을 입력하세요', hintStyle: TextStyle(color: Color(0x66D8B4FE), fontSize: 15), border: InputBorder.none)))),
        _IconButton(icon: isLoading ? Icons.hourglass_empty : (hasText ? Icons.arrow_upward : Icons.mic), onTap: hasText ? onSubmit : null, isPrimary: hasText),
      ])),
    ]));
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap, this.isPrimary = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: isPrimary ? SpaceColors.neonPurple : const Color(0xFF2A2A4A), borderRadius: BorderRadius.circular(12), border: Border.all(color: isPrimary ? SpaceColors.neonPurple : const Color(0x4CA78BFA)), boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 20)));
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.onSelectType});
  final ValueChanged<String> onSelectType;
  @override
  Widget build(BuildContext context) => Container(width: 160, decoration: BoxDecoration(color: const Color(0xB21A1A2E), borderRadius: BorderRadius.circular(24), border: Border.all(color: SpaceColors.neonPurple.withOpacity(0.3))), padding: const EdgeInsets.all(8), child: Column(mainAxisSize: MainAxisSize.min, children: [
    _MenuItem(icon: Icons.image_outlined, label: '이미지 분석', onTap: () => onSelectType(InputType.image)),
    const Divider(color: Color(0x1AFFFFFF), height: 1),
    _MenuItem(icon: Icons.location_on_outlined, label: '장소 지정', onTap: () => onSelectType(InputType.text)),
  ]));
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(visualDensity: VisualDensity.compact, leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0x33A78BFA), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)), title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)), onTap: onTap);
}
