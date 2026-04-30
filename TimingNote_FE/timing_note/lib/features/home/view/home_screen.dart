import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../todo/model/todo.dart';
import '../../todo/viewmodel/todo_input_viewmodel.dart';
import '../../todo/viewmodel/todo_list_viewmodel.dart';

// ── 디자인 상수 ─────────────────────────────────────────────────────
const _kBgDark = Color(0xFF050510);
const _kBgDeep = Color(0xFF110B1F);
const _kPurpleAccent = Color(0xFFA78BFA);
const _kPinkAccent = Color(0xFFF472B6);
const _kSurfaceDark = Color(0xE50F0F1A);

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
        SnackBar(content: Text(next.error ?? '등록 중 오류가 발생했어요'), backgroundColor: Colors.red.shade800),
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
      backgroundColor: _kBgDark,
      body: Stack(
        children: [
          // LAYER 1: 배경 & 타임라인
          const _RadialBackground(),
          const _StarField(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: _HomeHeader()),
                    if (todoListState.isLoading && todoListState.items.isEmpty)
                      const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _kPurpleAccent)))
                    else if (todoListState.items.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text('아직 등록된 할 일이 없어요.\n아래에서 첫 번째 기록을 남겨보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.5))),
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
    );
  }
}

// ── 하위 위젯: 플로팅 태그 영역 ──────────────────────────────────────────
class _FloatingTagArea extends StatefulWidget {
  const _FloatingTagArea({required this.isFocused, required this.onTagTap});
  final bool isFocused;
  final ValueChanged<String> onTagTap;

  @override
  State<_FloatingTagArea> createState() => _FloatingTagAreaState();
}

class _FloatingTagAreaState extends State<_FloatingTagArea> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: widget.isFocused ? 1.0 : 0.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAnimatedTag(left: 30, top: 40, label: '스타벅스 강남점', color: const Color(0xFFFCD34D), offsetMultiplier: 1.0),
          _buildAnimatedTag(right: 40, top: 120, label: '내일 오후 3시', color: const Color(0xFFFDBA74), offsetMultiplier: -0.7),
          _buildAnimatedTag(left: 80, top: 220, label: '매주 월요일', color: const Color(0xFFFCD34D), offsetMultiplier: 1.3, small: true),
          _buildAnimatedTag(right: 20, top: 280, label: '다이소', color: const Color(0xFFFDBA74), offsetMultiplier: -1.2, small: true),
          _buildAnimatedTag(left: 160, top: 20, label: '오늘 저녁', color: const Color(0xFFA78BFA), offsetMultiplier: 0.9, small: true),
        ],
      ),
    );
  }

  Widget _buildAnimatedTag({double? left, double? top, double? right, double? bottom, required String label, required Color color, required double offsetMultiplier, bool small = false}) {
    return Positioned(
      left: left, top: top, right: right, bottom: bottom,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 20 * math.sin(_floatController.value * 2 * math.pi) * offsetMultiplier),
          child: child,
        ),
        child: _ConstellationTag(label: label, glowColor: color, small: small, onTap: () => widget.onTagTap(label)),
      ),
    );
  }
}

class _ConstellationTag extends StatelessWidget {
  const _ConstellationTag({required this.label, required this.glowColor, required this.onTap, this.small = false});
  final String label;
  final Color glowColor;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final double starSize = small ? 4.0 : 4.6;
    final double crossSize = small ? 20.0 : 23.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: crossSize, height: crossSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: crossSize, height: 1.15, color: Colors.white.withOpacity(0.5)),
                Container(width: 1.15, height: crossSize, color: Colors.white.withOpacity(0.5)),
                Container(
                  width: starSize, height: starSize,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 3),
                    BoxShadow(color: glowColor.withOpacity(0.4), blurRadius: 24, spreadRadius: 8),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: small ? 13 : 15, fontWeight: FontWeight.w600, fontFamily: 'Inter', letterSpacing: 0.5, shadows: [const Shadow(color: Colors.black, blurRadius: 6), Shadow(color: glowColor, blurRadius: 12)])),
        ],
      ),
    );
  }
}

class _RadialBackground extends StatelessWidget {
  const _RadialBackground();
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.2, colors: [_kBgDeep, _kBgDark])));
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
            Row(children: [const Icon(Icons.location_on, color: _kPurpleAccent, size: 14), const SizedBox(width: 4), Text('현재 위치: 광주 상무지구', style: TextStyle(color: _kPurpleAccent.withOpacity(0.8), fontSize: 11))]),
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
    Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _kPinkAccent, shape: BoxShape.circle, border: Border.all(color: _kBgDark, width: 2), boxShadow: [BoxShadow(color: _kPinkAccent.withOpacity(0.8), blurRadius: 8)]), constraints: const BoxConstraints(minWidth: 20, minHeight: 20), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
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
    SizedBox(width: 40, child: Stack(alignment: Alignment.center, children: [Container(width: 2, color: Colors.white.withOpacity(0.2)), Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFE9D5FF), shape: BoxShape.circle))])),
    Expanded(child: isLeft ? _buildPlanet() : _buildContent(context)),
  ])));
  Widget _buildContent(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
    Text(distance, style: const TextStyle(color: _kPurpleAccent, fontSize: 10, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 4),
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: isLeft ? TextAlign.right : TextAlign.left),
    const SizedBox(height: 4),
    Text(memo, style: const TextStyle(color: Color(0x99E9D5FF), fontSize: 11), textAlign: isLeft ? TextAlign.right : TextAlign.left),
    const SizedBox(height: 10),
    _SmallActionBtn(label: '완료', isPrimary: true, onTap: onComplete),
  ]));
  Widget _buildPlanet() => Center(child: Container(width: 70, height: 70, decoration: BoxDecoration(image: DecorationImage(image: AssetImage(planetAsset), fit: BoxFit.contain))));
}

class _SmallActionBtn extends StatelessWidget {
  const _SmallActionBtn({required this.label, required this.isPrimary, required this.onTap});
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: isPrimary ? const Color(0x26A78BFA) : const Color(0xCC2A2A4A), borderRadius: BorderRadius.circular(10), border: Border.all(color: isPrimary ? const Color(0xFF8B5CF6) : const Color(0x4CA78BFA))), child: Text(label, style: TextStyle(color: isPrimary ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))));
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
    return AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding + (isInputMode ? 120 : 10)), decoration: const BoxDecoration(color: Color(0xF20F0F1A), border: Border(top: BorderSide(color: Color(0x1AFFFFFF)))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (showActionMenu) Padding(padding: const EdgeInsets.only(bottom: 8), child: _ActionMenu(onSelectType: onSelectType)),
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xE50F0F1A), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x33A78BFA), width: 2)), child: Row(children: [
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
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: isPrimary ? _kPurpleAccent : const Color(0xFF2A2A4A), borderRadius: BorderRadius.circular(12), border: Border.all(color: isPrimary ? _kPurpleAccent : const Color(0x4CA78BFA)), boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 20)));
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.onSelectType});
  final ValueChanged<String> onSelectType;
  @override
  Widget build(BuildContext context) => Container(width: 160, decoration: BoxDecoration(color: const Color(0xB21A1A2E), borderRadius: BorderRadius.circular(24), border: Border.all(color: _kPurpleAccent.withOpacity(0.3))), padding: const EdgeInsets.all(8), child: Column(mainAxisSize: MainAxisSize.min, children: [
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

class _StarField extends StatelessWidget {
  const _StarField();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarPainter(), size: Size.infinite);
}

class _StarPainter extends CustomPainter {
  static final _rng = math.Random(42);
  static final List<_Star> _stars = List.generate(40, (_) => _Star(x: _rng.nextDouble(), y: _rng.nextDouble(), radius: _rng.nextDouble() * 1.5 + 0.5, opacity: _rng.nextDouble() * 0.3 + 0.1));
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in _stars) {
      paint.color = (star.x > 0.5 ? _kPurpleAccent : Colors.white).withOpacity(star.opacity);
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.radius, paint);
    }
  }
  @override
  bool shouldRepaint(_StarPainter old) => false;
}

class _Star {
  const _Star({required this.x, required this.y, required this.radius, required this.opacity});
  final double x, y, radius, opacity;
}
