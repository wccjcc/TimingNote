import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../model/selected_kakao_place.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../viewmodel/todo_detail_viewmodel.dart';
import '../viewmodel/todo_edit_viewmodel.dart';

// -- 디자인 상수 (우주 테마) ------------------------------------------
const _kBgDark = Color(0xFF050510);
const _kBgDeep = Color(0xFF110B1F);
const _kPurpleAccent = Color(0xFFA78BFA);
const _kPinkAccent = Color(0xFFF472B6);
const _kSurfaceDark = Color(0xE50F0F1A);
const _kBorderWhite = Color(0x1AFFFFFF);

class TodoEditScreen extends ConsumerStatefulWidget {
  const TodoEditScreen({super.key, required this.todoId});
  final int todoId;
  @override
  ConsumerState<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends ConsumerState<TodoEditScreen> {
  final _contentController = TextEditingController();
  final _sharedUrlController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void dispose() {
    _contentController.dispose();
    _sharedUrlController.dispose();
    super.dispose();
  }

  void _initControllers(TodoEditState state) {
    if (_controllersInitialized || !state.isReady) return;
    _contentController.text = state.content ?? '';
    _sharedUrlController.text = state.sharedUrl ?? '';
    _controllersInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoEditProvider(widget.todoId));
    ref.listen<TodoEditState>(todoEditProvider(widget.todoId), (prev, next) {
      if (next.savedDetail != null && prev?.savedDetail == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }
    });
    _initControllers(state);
    return Scaffold(
      backgroundColor: _kBgDark,
      body: Stack(
        children: [
          const _EditRadialBackground(),
          const _EditStarField(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(state),
                Expanded(child: _buildBody(state)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TodoEditState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 24), onPressed: () => context.pop()),
          const Text('할 일 수정', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Galmuri11')),
          state.isSaving
              ? const SizedBox(width: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kPurpleAccent)))
              : TextButton(onPressed: state.canSave ? () => ref.read(todoEditProvider(widget.todoId).notifier).save() : null, child: Text('완료', style: TextStyle(color: state.canSave ? _kPurpleAccent : Colors.white24, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildBody(TodoEditState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: _kPurpleAccent));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        if (state.error != null) _ErrorBanner(message: state.error!),
        const _SectionTitle(title: '내용'),
        _GlassInputCard(child: TextField(controller: _contentController, maxLines: 4, style: const TextStyle(color: Colors.white, fontSize: 16), decoration: const InputDecoration(hintText: '무엇을 해야 하나요?', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none), onChanged: (v) => ref.read(todoEditProvider(widget.todoId).notifier).setContent(v))),
        const SizedBox(height: 24),
        const _SectionTitle(title: '카테고리'),
        _GlassInputCard(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: state.category, dropdownColor: _kSurfaceDark, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: _kPurpleAccent), items: TodoCategory.labels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 15)))).toList(), onChanged: (v) => ref.read(todoEditProvider(widget.todoId).notifier).setCategory(v!)))),
        const SizedBox(height: 24),
        const _SectionTitle(title: '장소'),
        _PlaceTile(todoId: widget.todoId),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const _SectionTitle(title: '시간 조건'), TextButton.icon(onPressed: () => _showAddTimeConditionSheet(context), icon: const Icon(Icons.add, size: 16, color: Colors.cyanAccent), label: const Text('추가', style: TextStyle(color: Colors.cyanAccent, fontSize: 13)))]),
        _TimeConditionList(todoId: widget.todoId, conditions: state.timeConditions ?? []),
        const SizedBox(height: 24),
        const _SectionTitle(title: '이미지'),
        _ImageSection(todoId: widget.todoId),
        const SizedBox(height: 24),
        const _SectionTitle(title: '참조 링크'),
        _GlassInputCard(child: TextField(controller: _sharedUrlController, style: const TextStyle(color: Colors.cyan, fontSize: 14), decoration: const InputDecoration(hintText: 'https://...', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none, prefixIcon: Icon(Icons.link, color: Colors.cyan, size: 20)), onChanged: (v) => ref.read(todoEditProvider(widget.todoId).notifier).setSharedUrl(v))),
        const SizedBox(height: 100),
      ],
    );
  }

  void _showAddTimeConditionSheet(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => _AddTimeConditionSheet(onAdd: (tc) => ref.read(todoEditProvider(widget.todoId).notifier).addTimeCondition(tc)));
  }
}

class _AddTimeConditionSheet extends StatefulWidget {
  const _AddTimeConditionSheet({required this.onAdd});
  final ValueChanged<TimeConditionRequest> onAdd;
  @override
  State<_AddTimeConditionSheet> createState() => _AddTimeConditionSheetState();
}

class _AddTimeConditionSheetState extends State<_AddTimeConditionSheet> {
  String _type = ConditionType.datetime;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;
  bool _timeEnabled = true; // 시간 활성화 여부 토글
  int _startHour = DateTime.now().hour;
  int _startMinute = (DateTime.now().minute ~/ 5) * 5;
  int _endHour = (DateTime.now().hour + 1) % 24;
  int _endMinute = (DateTime.now().minute ~/ 5) * 5;
  final Set<String> _selectedDays = {};
  static const _dayLabels = {'MON': '월', 'TUE': '화', 'WED': '수', 'THU': '목', 'FRI': '금', 'SAT': '토', 'SUN': '일'};

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: const BoxDecoration(color: _kSurfaceDark, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          const Text('시간 조건 설정', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Galmuri11')),
          const SizedBox(height: 20),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildTypeChip('정확한 일시', ConditionType.datetime), _buildTypeChip('날짜 범위', ConditionType.dateRange), _buildTypeChip('매주 반복', ConditionType.week), _buildTypeChip('시간 범위', ConditionType.timeRange)])),
          const SizedBox(height: 32),
          if (_type == ConditionType.week) _buildDaySelector() else if (_type != ConditionType.timeRange) _buildDateSelector(),
          const SizedBox(height: 24),
          if (_type != ConditionType.date) _buildTimeToggle(),
          const SizedBox(height: 16),
          if (_type != ConditionType.date && _timeEnabled) ...[
            _buildTimeSection('시작 시간', _startHour, _startMinute, (h) => _startHour = h, (m) => _startMinute = m),
            const SizedBox(height: 20),
            _buildTimeSection('종료 시간', _endHour, _endMinute, (h) => _endHour = h, (m) => _endMinute = m),
          ],
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _kPurpleAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: _kPurpleAccent.withOpacity(0.5)), onPressed: _submit, child: const Text('조건 적용하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildTimeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('시간 구체적 설정', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        Switch(value: _timeEnabled, onChanged: (v) => setState(() => _timeEnabled = v), activeColor: _kPurpleAccent, activeTrackColor: _kPurpleAccent.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _type == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() {
          _type = value;
          if (_type == ConditionType.timeRange) _timeEnabled = true;
        }),
        selectedColor: _kPurpleAccent.withOpacity(0.3),
        backgroundColor: const Color(0xFF1A1A2E), // 더 어두운 배경으로 고정
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70, // 글자색을 흰색 계열로 명시
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? _kPurpleAccent : Colors.white10),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildDateSelector() {
    final isRange = _type == ConditionType.dateRange;
    final dateText = isRange ? '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day} ~ ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}' : '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일';
    return InkWell(onTap: () async {
      if (isRange) {
        final range = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => _buildPickerTheme(child!));
        if (range != null) setState(() => _selectedDateRange = range);
      } else {
        final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => _buildPickerTheme(child!));
        if (date != null) setState(() => _selectedDate = date);
      }
    }, child: _GlassInputCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(isRange ? Icons.date_range : Icons.calendar_month, color: _kPurpleAccent, size: 20), const SizedBox(width: 12), Text(dateText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)), const Spacer(), const Icon(Icons.chevron_right, color: Colors.white24)]))));
  }

  Widget _buildPickerTheme(Widget child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _kPurpleAccent, onPrimary: Colors.white, surface: _kBgDeep, onSurface: Colors.white)), child: child);

  Widget _buildDaySelector() {
    return Wrap(spacing: 10, runSpacing: 10, children: _dayLabels.entries.map((e) {
      final isSelected = _selectedDays.contains(e.key);
      return GestureDetector(onTap: () => setState(() => isSelected ? _selectedDays.remove(e.key) : _selectedDays.add(e.key)), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 44, height: 44, decoration: BoxDecoration(color: isSelected ? _kPurpleAccent : Colors.white10, shape: BoxShape.circle, border: Border.all(color: isSelected ? _kPurpleAccent : Colors.white10), boxShadow: isSelected ? [BoxShadow(color: _kPurpleAccent.withOpacity(0.4), blurRadius: 10)] : null), child: Center(child: Text(e.value, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)))));
    }).toList());
  }

  Widget _buildTimeSection(String title, int hour, int minute, ValueChanged<int> onHourChanged, ValueChanged<int> onMinuteChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Container(height: 100, decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Stack(alignment: Alignment.center, children: [
        Container(height: 36, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: _kPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildWheel(count: 24, initialValue: hour, onChanged: (v) => setState(() => onHourChanged(v)), suffix: '시'),
          const Text(':', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          _buildWheel(count: 12, initialValue: minute ~/ 5, onChanged: (v) => setState(() => onMinuteChanged(v * 5)), itemBuilder: (i) => (i * 5).toString().padLeft(2, '0'), suffix: '분'),
        ])
      ]))
    ]);
  }

  Widget _buildWheel({required int count, required int initialValue, required ValueChanged<int> onChanged, String? Function(int)? itemBuilder, String suffix = ''}) {
    return SizedBox(width: 70, child: ListWheelScrollView.useDelegate(itemExtent: 36, physics: const FixedExtentScrollPhysics(), useMagnifier: true, magnification: 1.2, overAndUnderCenterOpacity: 0.3, onSelectedItemChanged: onChanged, controller: FixedExtentScrollController(initialItem: (itemBuilder != null) ? initialValue ~/ 5 : initialValue), childDelegate: ListWheelChildBuilderDelegate(childCount: count, builder: (context, index) {
      final text = itemBuilder != null ? itemBuilder(index) : index.toString().padLeft(2, '0');
      return Center(child: Text('$text$suffix', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)));
    })));
  }

  void _submit() {
    String? startTimeStr; String? endTimeStr;
    if (_timeEnabled) {
      startTimeStr = '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}';
      endTimeStr = '${_endHour.toString().padLeft(2, '0')}:${_endMinute.toString().padLeft(2, '0')}';
    }
    if (_type == ConditionType.dateRange && _selectedDateRange != null) {
      widget.onAdd(TimeConditionRequest(conditionType: _type, startDate: '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')}', endDate: '${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}', startTime: startTimeStr, endTime: endTimeStr));
    } else {
      widget.onAdd(TimeConditionRequest(conditionType: _type, startDate: '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}', startTime: startTimeStr, endTime: endTimeStr, daysOfWeek: _selectedDays.toList()));
    }
    Navigator.pop(context);
  }
}

class _GlassInputCard extends StatelessWidget {
  const _GlassInputCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))), child: child);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)));
}

class _TimeConditionList extends ConsumerWidget {
  const _TimeConditionList({required this.todoId, required this.conditions});
  final int todoId;
  final List<TimeConditionRequest> conditions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conditions.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('설정된 시간 조건이 없습니다.', style: TextStyle(color: Colors.white24, fontSize: 13)));
    return Column(children: List.generate(conditions.length, (i) {
      final tc = conditions[i];
      return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), child: ListTile(dense: true, title: Text(_describeRequest(tc), style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => ref.read(todoEditProvider(todoId).notifier).removeTimeCondition(i))));
    }));
  }
  String _describeRequest(TimeConditionRequest tc) {
    switch (tc.conditionType) {
      case ConditionType.datetime: return '${tc.startDate ?? ''} ${tc.startTime ?? ''}';
      case ConditionType.date: return tc.startDate ?? '';
      case ConditionType.dateRange: return '${tc.startDate} ~ ${tc.endDate}';
      case ConditionType.week: return '${(tc.daysOfWeek ?? []).join(', ')} ${tc.startTime ?? ''}';
      case ConditionType.timeRange: return '${tc.startTime} ~ ${tc.endTime}';
      default: return tc.rawExpression ?? tc.conditionType;
    }
  }
}

const _kMaxImages = 3;

class _ImageSection extends ConsumerWidget {
  const _ImageSection({required this.todoId});
  final int todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(
      todoEditProvider(todoId).select((s) => s.imageUrls ?? []),
    );
    final canAdd = urls.length < _kMaxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 추가 버튼
              if (canAdd)
                GestureDetector(
                  onTap: () => _pickImage(context, ref),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.white38, size: 28),
                        SizedBox(height: 6),
                        Text('사진 추가', style: TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              // 기존 이미지 목록
              ...urls.map((url) => _ImageTile(
                url: url,
                onDelete: () => ref
                    .read(todoEditProvider(todoId).notifier)
                    .removeImageUrl(url),
              )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            '${urls.length} / $_kMaxImages',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    // presigned URL BE 엔드포인트 연결 후 실제 업로드 구현 예정
    // 현재는 갤러리 접근만 확인
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('이미지 업로드 기능 준비 중입니다'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1A1A2E),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.url, required this.onDelete});
  final String url;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              url,
              width: 100,
              height: 104,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))), child: Row(children: [const Icon(Icons.error_outline, color: Colors.redAccent, size: 20), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13)))]));
}

class _EditRadialBackground extends StatelessWidget {
  const _EditRadialBackground();
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.bottomLeft, radius: 1.5, colors: [_kBgDeep, _kBgDark])));
}

class _EditStarField extends StatelessWidget {
  const _EditStarField();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _EditStarPainter(), size: ui.Size.infinite);
}

class _EditStarPainter extends CustomPainter {
  static final _rng = math.Random(202);
  static final List<_Star> _stars = List.generate(30, (_) => _Star(x: _rng.nextDouble(), y: _rng.nextDouble(), radius: _rng.nextDouble() * 1.2 + 0.3, opacity: _rng.nextDouble() * 0.2 + 0.1));
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint();
    for (final star in _stars) {
      paint.color = Colors.white.withOpacity(star.opacity);
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.radius, paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _Star {
  const _Star({required this.x, required this.y, required this.radius, required this.opacity});
  final double x, y, radius, opacity;
}

/// 장소 선택 타일 — 탭하면 PlaceSearchScreen으로 이동하고,
/// 결과가 오면 todoDetailProvider.setPlace() 즉시 호출.
class _PlaceTile extends ConsumerWidget {
  const _PlaceTile({required this.todoId});

  final int todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(todoDetailProvider(todoId));
    final place = detailState.detail?.primaryPlace;
    final label = detailState.detail?.resolvedPlaceLabel;

    final hasPlace = label != null && label.isNotEmpty && label != '장소 미정';

    return GestureDetector(
      onTap: () => _openPlaceSearch(context, ref, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(
              hasPlace ? Icons.location_on : Icons.location_on_outlined,
              color: hasPlace ? _kPurpleAccent : Colors.white24,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPlace ? label! : '장소를 선택하세요',
                    style: TextStyle(
                      color: hasPlace ? Colors.white : Colors.white24,
                      fontSize: 15,
                    ),
                  ),
                  if (hasPlace && place?.roadAddress != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      place!.roadAddress!,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlaceSearch(BuildContext context, WidgetRef ref, String? currentLabel) async {
    final keyword = currentLabel != null && currentLabel != '장소 미정' ? currentLabel : '';
    final uri = keyword.isNotEmpty
        ? '/place-search?keyword=${Uri.encodeComponent(keyword)}'
        : '/place-search';

    final result = await context.push<SelectedKakaoPlace>(uri);
    if (result == null || !context.mounted) return;

    await ref.read(todoDetailProvider(todoId).notifier).setPlace(
          kakaoPlaceId: result.kakaoPlaceId,
          placeName: result.name,
          addressName: result.address,
          roadAddressName: result.roadAddress,
          categoryGroupCode: result.categoryGroupCode,
          categoryGroupName: result.categoryGroupName,
          phone: result.phone,
          placeUrl: result.placeUrl,
          longitude: result.longitude,
          latitude: result.latitude,
        );
  }
}
