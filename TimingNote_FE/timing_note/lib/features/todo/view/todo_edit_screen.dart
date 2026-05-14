import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';

import '../model/selected_kakao_place.dart';
import '../model/time_condition.dart';
import '../model/todo.dart';
import '../util/time_condition_formatter.dart';
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

  // 타입별 시간 정책:
  // - DATE: 시간 사용 안 함 (토글 없음, 시간 영역 숨김)
  // - DATETIME, DATE_RANGE, WEEK: 시간 선택 (토글로 켜고 끔, OFF면 시간 정보 없음 = 24시간 적용)
  // - TIME_RANGE: 시간 필수 (토글 없음, 항상 표시 — 시간이 곧 핵심 정보)
  bool get _timeRequired => _type == ConditionType.timeRange;
  bool get _timeAvailable => _type != ConditionType.date;
  bool get _showTimeSection =>
      _timeAvailable && (_timeRequired || _timeEnabled);
  bool get _showTimeToggle => _timeAvailable && !_timeRequired;

  /// 시작시간이 변경되어 종료시간이 같거나 이전이 되면 종료시간을 시작+5분으로 자동 보정.
  /// 23:55 이후 시작 시에는 종료를 23:59로 clamp (자정 넘김 금지 정책).
  void _normalizeEndAfterStart() {
    final start = _startHour * 60 + _startMinute;
    final end = _endHour * 60 + _endMinute;
    if (end <= start) {
      var newEnd = start + 5;
      if (newEnd > 23 * 60 + 59) newEnd = 23 * 60 + 59;
      _endHour = newEnd ~/ 60;
      _endMinute = newEnd % 60;
    }
  }

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
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildTypeChip('날짜', ConditionType.datetime), _buildTypeChip('기간', ConditionType.dateRange), _buildTypeChip('매주', ConditionType.week), _buildTypeChip('시간대', ConditionType.timeRange)])),
          const SizedBox(height: 32),
          if (_type == ConditionType.week) _buildDaySelector() else if (_type != ConditionType.timeRange) _buildDateSelector(),
          const SizedBox(height: 24),
          if (_showTimeToggle) _buildTimeToggle(),
          if (_showTimeSection) ...[
            const SizedBox(height: 16),
            // 시작 시간과 종료 시간을 가로로 배치 — 한 눈에 비교 가능 + 세로 공간 절약.
            // crossAxisAlignment.end: 두 섹션 wheel 박스 하단을 맞춰 가운데 '~'가 wheel 사이에 위치.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildStartTimeSection()),
                const Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Text(
                    '~',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: _buildEndTimeSection()),
              ],
            ),
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
        const Text('시간 설정 (선택)', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
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
          // TIME_RANGE는 시간 필수 → 강제 활성
          // DATE는 시간 없음 → 강제 비활성
          // 그 외(DATETIME, DATE_RANGE, WEEK)는 사용자 토글 그대로 둠
          if (_type == ConditionType.timeRange) {
            _timeEnabled = true;
          } else if (_type == ConditionType.date) {
            _timeEnabled = false;
          }
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
    // 과거 날짜는 알림이 의미 없으므로 오늘 이전 선택 불가. 시·분 영향 없이 자정 기준으로 정규화.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = today.add(const Duration(days: 365));
    return InkWell(onTap: () async {
      if (isRange) {
        // Material의 showDateRangePicker는 fullscreen Scaffold라 다이얼로그 톤이 깨진다.
        // table_calendar 기반 자체 모달을 띄워 단일 날짜 picker와 일관된 모달 UX 유지.
        final range = await showDialog<DateTimeRange>(
          context: context,
          builder: (_) => _RangeCalendarDialog(
            initial: _selectedDateRange,
            firstDate: today,
            lastDate: lastDate,
          ),
        );
        if (range != null) setState(() => _selectedDateRange = range);
      } else {
        // 단일 날짜도 자체 캘린더 모달로 통일 — Material showDatePicker는 다이얼로그긴 하지만
        // 디자인 일관성과 한글/보라 톤 완전 통제를 위해 직접 그린다.
        final date = await showDialog<DateTime>(
          context: context,
          builder: (_) => _SingleCalendarDialog(
            initial: _selectedDate,
            firstDate: today,
            lastDate: lastDate,
          ),
        );
        if (date != null) setState(() => _selectedDate = date);
      }
    }, child: _GlassInputCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(isRange ? Icons.date_range : Icons.calendar_month, color: _kPurpleAccent, size: 20), const SizedBox(width: 12), Text(dateText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)), const Spacer(), const Icon(Icons.chevron_right, color: Colors.white24)]))));
  }

  Widget _buildDaySelector() {
    return Wrap(spacing: 10, runSpacing: 10, children: _dayLabels.entries.map((e) {
      final isSelected = _selectedDays.contains(e.key);
      return GestureDetector(onTap: () => setState(() => isSelected ? _selectedDays.remove(e.key) : _selectedDays.add(e.key)), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 44, height: 44, decoration: BoxDecoration(color: isSelected ? _kPurpleAccent : Colors.white10, shape: BoxShape.circle, border: Border.all(color: isSelected ? _kPurpleAccent : Colors.white10), boxShadow: isSelected ? [BoxShadow(color: _kPurpleAccent.withOpacity(0.4), blurRadius: 10)] : null), child: Center(child: Text(e.value, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)))));
    }).toList());
  }

  /// 시작 시간 섹션 — hour 0~23, minute 0~55(5분).
  /// 단 시작 hour가 23일 때는 분 max=50으로 제한 — 5분 단위 wheel 특성상 23:55 시작이면 종료를
  /// 5분 간격으로 표현 못 함(24:00은 정책상 금지). 즉 23:50까지만 시작 가능.
  Widget _buildStartTimeSection() {
    final startMinuteMax = _startHour == 23 ? 11 : 12; // 23시면 0~50 (11개), 그 외 0~55 (12개)
    final startMinuteIdx = (_startMinute ~/ 5).clamp(0, startMinuteMax - 1);
    return _buildTimeSectionFrame(
      title: '시작 시간',
      hourCount: 24,
      hourInitial: _startHour,
      hourValueFrom: (idx) => idx,
      hourLabelFrom: (idx) => idx.toString().padLeft(2, '0'),
      minuteCount: startMinuteMax,
      minuteInitial: startMinuteIdx,
      minuteValueFrom: (idx) => idx * 5,
      onHourChanged: (h) => setState(() {
        _startHour = h;
        // 23시로 바꾸면서 분이 50을 넘으면 50으로 clamp
        if (_startHour == 23 && _startMinute > 50) _startMinute = 50;
        _normalizeEndAfterStart();
      }),
      onMinuteChanged: (m) => setState(() {
        _startMinute = m;
        _normalizeEndAfterStart();
      }),
    );
  }

  /// 종료 시간 섹션 — hour/minute range를 시작시간 이상으로 동적 제한.
  /// - hour: _startHour ~ 23 (시작 hour 이전 항목 자체가 노출되지 않음)
  /// - minute (같은 hour일 때): startMinute+5 ~ 55만 노출, 5분 단위
  /// - minute (다른 hour일 때): 0 ~ 55 자유, 5분 단위
  /// → wheel scroll만으로는 invalid 상태(종료 ≤ 시작)에 도달할 수 없음.
  Widget _buildEndTimeSection() {
    final hourCount = 24 - _startHour;
    final hourInitialOffset = (_endHour - _startHour).clamp(0, hourCount - 1);

    // 같은 hour일 때 분 wheel의 시작 값은 startMinute + 5 (5분 간격으로 올림)
    final isSameHour = _endHour == _startHour;
    final minuteFloor = isSameHour ? (((_startMinute ~/ 5) + 1) * 5) : 0;
    final minuteCount = (60 - minuteFloor) ~/ 5;
    // minuteCount가 0이면(23:55+ 극단 케이스) clamp(0, -1)에서 ArgumentError 발생.
    // 시작 wheel max로 사실상 차단되지만 안전망으로 0으로 fallback (_buildWheel이 단일 행 표시).
    final endMinuteIdx = minuteCount > 0
        ? ((_endMinute - minuteFloor) ~/ 5).clamp(0, minuteCount - 1)
        : 0;

    return _buildTimeSectionFrame(
      title: '종료 시간',
      hourCount: hourCount,
      hourInitial: hourInitialOffset,
      hourValueFrom: (idx) => _startHour + idx,
      hourLabelFrom: (idx) => (_startHour + idx).toString().padLeft(2, '0'),
      minuteCount: minuteCount,
      minuteInitial: endMinuteIdx,
      minuteValueFrom: (idx) => minuteFloor + idx * 5,
      onHourChanged: (h) => setState(() {
        _endHour = h;
        _enforceEndAfterStart();
      }),
      onMinuteChanged: (m) => setState(() {
        _endMinute = m;
        _enforceEndAfterStart();
      }),
    );
  }

  /// 종료가 시작 이하가 되면 강제 보정 — 시작+5분으로.
  /// 종료 wheel 자체 변경에서만 사용 (시작 변경은 _normalizeEndAfterStart 사용).
  void _enforceEndAfterStart() {
    final start = _startHour * 60 + _startMinute;
    final end = _endHour * 60 + _endMinute;
    if (end <= start) {
      var newEnd = start + 5;
      if (newEnd > 23 * 60 + 59) newEnd = 23 * 60 + 59;
      _endHour = newEnd ~/ 60;
      _endMinute = newEnd % 60;
    }
  }

  /// 시작/종료 공용 시간 섹션 프레임. hour/minute wheel을 한 묶음으로 구성.
  /// `hourValueFrom`/`hourLabelFrom`으로 wheel index를 실제 hour 값/라벨로 매핑 (offset 분리).
  Widget _buildTimeSectionFrame({
    required String title,
    required int hourCount,
    required int hourInitial,
    required int Function(int idx) hourValueFrom,
    required String Function(int idx) hourLabelFrom,
    required int minuteCount,
    required int minuteInitial,
    required int Function(int idx) minuteValueFrom,
    required ValueChanged<int> onHourChanged,
    required ValueChanged<int> onMinuteChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Container(
            height: 36,
            width: double.infinity,
            // 가로 배치로 박스 자체가 좁아져 좌우 여유를 줄여(20 → 12) wheel과 highlight band가
            // 자연스럽게 맞물리도록 한다.
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _kPurpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildWheel(
              count: hourCount,
              initialValue: hourInitial,
              labelFrom: hourLabelFrom,
              onChanged: (idx) => onHourChanged(hourValueFrom(idx)),
              suffix: '시',
            ),
            const Text(':', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            _buildWheel(
              count: minuteCount,
              initialValue: minuteInitial,
              labelFrom: (idx) => (minuteValueFrom(idx)).toString().padLeft(2, '0'),
              onChanged: (idx) => onMinuteChanged(minuteValueFrom(idx)),
              suffix: '분',
            ),
          ])
        ]),
      ),
    ]);
  }

  /// 일반 wheel 위젯. `labelFrom`으로 index → 표시 라벨 매핑.
  Widget _buildWheel({
    required int count,
    required int initialValue,
    required String Function(int idx) labelFrom,
    required ValueChanged<int> onChanged,
    String suffix = '',
  }) {
    // count가 1 이하면 wheel scroll이 무의미 — 단일 행 표시. (시작이 23:55 이상인 극단 케이스)
    if (count <= 0) {
      return SizedBox(width: 56, height: 100, child: Center(
        child: Text('${labelFrom(0)}$suffix',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      ));
    }
    return SizedBox(
      width: 56,
      child: ListWheelScrollView.useDelegate(
        // count가 변경되면(예: 시작 시간 변경 시 종료 wheel의 항목 수가 줄어드는 경우) key가 달라져
        // wheel widget이 새로 만들어진다. controller도 새로 생성되어 initialValue 위치로 점프.
        // count가 같으면 동일 widget 재사용 → 사용자 스크롤 동작 유지.
        key: ValueKey('wheel-$count'),
        itemExtent: 36,
        physics: const FixedExtentScrollPhysics(),
        useMagnifier: true,
        magnification: 1.2,
        overAndUnderCenterOpacity: 0.3,
        onSelectedItemChanged: onChanged,
        controller: FixedExtentScrollController(initialItem: initialValue),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) => Center(
            child: Text('${labelFrom(index)}$suffix',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
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
      return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), child: ListTile(dense: true, title: Text(formatTimeConditionRequest(tc), style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => ref.read(todoEditProvider(todoId).notifier).removeTimeCondition(i))));
    }));
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
    final previewMap = ref.watch(
      todoEditProvider(todoId).select((s) => s.imagePreviewBytes),
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
                previewBytes: previewMap[url],
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

    await ref.read(todoEditProvider(todoId).notifier).uploadPickedImage(picked);

  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.url, required this.onDelete, this.previewBytes});
  final String url;
  final VoidCallback onDelete;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: previewBytes != null
                ? Image.memory(
                    previewBytes!,
                    width: 100,
                    height: 104,
                    fit: BoxFit.cover,
                  )
                : Image.network(
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
/// 결과가 ALIAS면 setAliasPlace, EXTERNAL이면 setExternalPlace 즉시 호출.
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

    final result = await context.push<SelectedPlace>(uri);
    if (result == null || !context.mounted) return;

    final notifier = ref.read(todoDetailProvider(todoId).notifier);
    switch (result) {
      case SelectedAliasPlace alias:
        await notifier.setAliasPlace(userPlaceId: alias.userPlaceId);
      case SelectedExternalPlace external:
        await notifier.setExternalPlace(place: external);
    }
  }
}

// ── 날짜 범위 캘린더 모달 ────────────────────────────────────────────────
/// Material `showDateRangePicker`는 fullscreen Scaffold라 단일 날짜 picker(다이얼로그)와
/// UX 톤이 어긋난다. `table_calendar` 기반으로 자체 모달을 구성해 우주 테마(보라/다크)와
/// 일관성을 유지한다.
///
/// 동작:
/// - 첫 탭으로 range 시작 지정
/// - 두 번째 탭으로 range 종료 지정 (시작 이전 날짜를 탭하면 시작이 재설정됨)
/// - 종료 미지정 상태로 적용 시 시작 = 종료(단일일 = 하루 범위)로 처리
class _RangeCalendarDialog extends StatefulWidget {
  const _RangeCalendarDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_RangeCalendarDialog> createState() => _RangeCalendarDialogState();
}

class _RangeCalendarDialogState extends State<_RangeCalendarDialog> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initial?.start;
    _rangeEnd = widget.initial?.end;
    _focusedDay = _rangeStart ?? widget.firstDate;
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focused;
    });
  }

  bool get _canApply => _rangeStart != null;

  void _apply() {
    if (!_canApply) return;
    final start = _rangeStart!;
    // 종료 미선택 시 시작과 동일 (하루 범위로 취급).
    final end = _rangeEnd ?? start;
    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: _kPurpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '기간 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 캘린더
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              locale: 'ko_KR',
              startingDayOfWeek: StartingDayOfWeek.monday,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              onRangeSelected: _onRangeSelected,
              onPageChanged: (day) => _focusedDay = day,
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: _kPurpleAccent),
                rightChevronIcon: Icon(Icons.chevron_right, color: _kPurpleAccent),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white60, fontSize: 12),
                weekendStyle: TextStyle(color: _kPinkAccent, fontSize: 12),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: _kPinkAccent),
                disabledTextStyle: const TextStyle(color: Colors.white24),
                todayTextStyle: const TextStyle(
                  color: _kPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                todayDecoration: BoxDecoration(
                  color: _kPurpleAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: const BoxDecoration(
                  color: _kPurpleAccent,
                  shape: BoxShape.circle,
                ),
                rangeStartTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                rangeEndDecoration: const BoxDecoration(
                  color: _kPurpleAccent,
                  shape: BoxShape.circle,
                ),
                rangeEndTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                // 사이 셀의 box decoration은 비워두고 rangeHighlightColor 만으로
                // 셀들 사이 공간까지 이어지는 연속 highlight band를 그린다 (Apple Calendar 스타일).
                // 각 셀 박스가 분리되어 보이는 안 자연스러운 효과 제거.
                withinRangeDecoration: const BoxDecoration(),
                withinRangeTextStyle: const TextStyle(color: Colors.white),
                rangeHighlightColor: _kPurpleAccent.withOpacity(0.18),
                rangeHighlightScale: 1.0,
              ),
            ),
            const SizedBox(height: 8),

            // 안내 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _rangeStart == null
                    ? '시작 날짜를 먼저 선택하세요'
                    : (_rangeEnd == null
                        ? '종료 날짜를 선택하거나 시작 날짜만으로 적용할 수 있어요'
                        : '${_rangeStart!.month}월 ${_rangeStart!.day}일 ~ ${_rangeEnd!.month}월 ${_rangeEnd!.day}일'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canApply ? _apply : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurpleAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kPurpleAccent.withOpacity(0.3),
                      disabledForegroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 단일 날짜 캘린더 모달 ──────────────────────────────────────────────
/// 단일 날짜 선택용 캘린더 모달. _RangeCalendarDialog와 동일 톤(보라/다크) 유지.
/// Material showDatePicker도 다이얼로그긴 하지만, 디자인 일관성과 한글/색상 완전 제어를 위해
/// table_calendar 기반으로 직접 그린다.
class _SingleCalendarDialog extends StatefulWidget {
  const _SingleCalendarDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_SingleCalendarDialog> createState() => _SingleCalendarDialogState();
}

class _SingleCalendarDialogState extends State<_SingleCalendarDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initial;
    _focusedDay = widget.initial;
  }

  void _apply() => Navigator.of(context).pop(_selectedDay);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: _kPurpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '날짜 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 캘린더
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              locale: 'ko_KR',
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (day) => _focusedDay = day,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: _kPurpleAccent),
                rightChevronIcon: Icon(Icons.chevron_right, color: _kPurpleAccent),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white60, fontSize: 12),
                weekendStyle: TextStyle(color: _kPinkAccent, fontSize: 12),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: _kPinkAccent),
                disabledTextStyle: const TextStyle(color: Colors.white24),
                todayTextStyle: const TextStyle(
                  color: _kPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                todayDecoration: BoxDecoration(
                  color: _kPurpleAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: _kPurpleAccent,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
