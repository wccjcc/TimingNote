import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mypage/model/user_place.dart';
import '../../mypage/service/user_place_service.dart';
import '../model/todo.dart';
import '../viewmodel/todo_input_viewmodel.dart';

// InputType 상수를 화면에서 편하게 쓰기 위한 별칭
typedef TodoInputType = InputType;

class TodoInputScreen extends ConsumerStatefulWidget {
  const TodoInputScreen({super.key});

  @override
  ConsumerState<TodoInputScreen> createState() => _TodoInputScreenState();
}

class _TodoInputScreenState extends ConsumerState<TodoInputScreen> {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedInputType = TodoInputType.text;
  List<UserPlace>? _userPlaces;

  @override
  void initState() {
    super.initState();
    _loadUserPlaces();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserPlaces() async {
    try {
      final list = await ref.read(userPlaceServiceProvider).getUserPlaces();
      if (!mounted) return;
      setState(() => _userPlaces = list);
    } catch (_) {
      // 무시 — 빈 목록으로 처리 (사용자가 등록 안 했거나 네트워크 실패)
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoInputProvider);

    // 완료 → 상세 화면으로 이동
    ref.listen<TodoInputState>(todoInputProvider, (prev, next) {
      if (next.isCompleted && next.createdTodoId != null) {
        // 짧은 딜레이 후 이동 (빌드 사이클 보호)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.pushReplacement('/todos/${next.createdTodoId}');
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('새 할 일'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: state.canSubmit
                ? () => ref.read(todoInputProvider.notifier).submit()
                : null,
            child: const Text('저장'),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, TodoInputState state) {
    // 제출 오버레이
    if (state.isSubmitting) {
      return const _LoadingOverlay(
        message: '저장 중…',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 입력 유형 선택 ─────────────────────────────────────────
          _InputTypeSelector(
            selected: _selectedInputType,
            onChanged: (type) {
              setState(() => _selectedInputType = type);
              ref.read(todoInputProvider.notifier).setInputType(type);
            },
          ),
          const SizedBox(height: 16),

          // ── 내 장소 태그 목록 (등록된 게 있을 때만, 클릭 시 ALIAS 명시 선택/교체) ──
          if (_userPlaces != null && _userPlaces!.isNotEmpty) ...[
            _UserPlaceTags(
              places: _userPlaces!,
              selectedId: state.selectedUserPlace?.id,
              onTap: (place) {
                final notifier = ref.read(todoInputProvider.notifier);
                if (state.selectedUserPlace?.id == place.id) {
                  notifier.clearUserPlace();
                } else {
                  notifier.setUserPlace(place); // 교체
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // ── 내용 입력 (선택된 ALIAS는 prefix chip으로 입력창 안에 표시) ──
          TextField(
            controller: _contentController,
            focusNode: _focusNode,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            decoration: InputDecoration(
              prefix: state.selectedUserPlace != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        avatar: const Icon(Icons.bookmark, size: 14),
                        label: Text(state.selectedUserPlace!.aliasName),
                        onDeleted: () =>
                            ref.read(todoInputProvider.notifier).clearUserPlace(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
              hintText: '할 일을 자연어로 입력하세요.\n예) 다음 주 월요일 오전에 홈플러스에서 우유 사기',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ref.read(todoInputProvider.notifier).setContent(v),
          ),

          const SizedBox(height: 16),

          // ── 오류 메시지 ───────────────────────────────────────────
          if (state.error != null)
            _ErrorBanner(
              message: state.error!,
              onRetry: () {
                ref.read(todoInputProvider.notifier).resetError();
              },
            ),

          const SizedBox(height: 8),

          // ── 안내 텍스트 ───────────────────────────────────────────
          Text(
            '장소, 날짜, 시간을 포함해 입력하면 AI가 자동으로 구조화합니다.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── 내 장소 태그 목록 ────────────────────────────────────────────────
/// 사용자가 등록한 별칭 모두를 ChoiceChip으로 표시.
/// - 클릭: ALIAS 명시 선택 (선택된 게 있으면 교체)
/// - 선택된 chip 다시 클릭: 해제
/// 선택된 ALIAS는 입력창 prefix chip으로 별도 표시됨.
class _UserPlaceTags extends StatelessWidget {
  const _UserPlaceTags({
    required this.places,
    required this.selectedId,
    required this.onTap,
  });

  final List<UserPlace> places;
  final int? selectedId;
  final ValueChanged<UserPlace> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: places.map((place) {
        final isSelected = selectedId == place.id;
        return ChoiceChip(
          avatar: Icon(
            isSelected ? Icons.bookmark : Icons.bookmark_outline,
            size: 14,
          ),
          label: Text(place.aliasName),
          selected: isSelected,
          onSelected: (_) => onTap(place),
        );
      }).toList(),
    );
  }
}

// ── 입력 유형 선택 ─────────────────────────────────────────────────
class _InputTypeSelector extends StatelessWidget {
  const _InputTypeSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _types = [
    (value: TodoInputType.text, label: '텍스트', icon: Icons.text_fields),
    (value: TodoInputType.voice, label: '음성', icon: Icons.mic),
    (value: TodoInputType.image, label: '이미지', icon: Icons.image),
    (value: TodoInputType.link, label: '링크', icon: Icons.link),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _types.map((t) {
        final isSelected = selected == t.value;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.icon, size: 16),
              const SizedBox(width: 4),
              Text(t.label),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onChanged(t.value),
        );
      }).toList(),
    );
  }
}

// ── 로딩 오버레이 ─────────────────────────────────────────────────
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── 오류 배너 ─────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('재시도'),
          ),
        ],
      ),
    );
  }
}
