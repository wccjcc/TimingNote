/// TimeCondition을 사용자 친화 한국어 문자열로 변환한다.
///
/// 핵심 원칙:
/// - null 필드는 표시에서 자연스럽게 생략 ("null"이라는 글자 자체가 노출되지 않도록)
/// - 날짜는 "M월 D일", 시간은 "HH:mm" 24시간제로 통일
/// - 요일은 단축어("월·수·금"), 평일/주말/매일 패턴은 그룹화
library;

import '../model/time_condition.dart';

/// TimeCondition(응답 모델) 한 건을 한 줄 라벨로 변환.
String formatTimeCondition(TimeCondition tc) {
  return _format(
    type: tc.conditionType,
    startDate: tc.startDate,
    endDate: tc.endDate,
    startTime: tc.startTime,
    endTime: tc.endTime,
    dayNames: tc.dayNames,
    rawExpression: tc.rawExpression,
  );
}

/// TimeConditionRequest(요청/수정 폼 모델) 한 건을 한 줄 라벨로 변환.
/// 수정 화면 등에서 사용.
String formatTimeConditionRequest(TimeConditionRequest tc) {
  return _format(
    type: tc.conditionType,
    startDate: tc.startDate,
    endDate: tc.endDate,
    startTime: tc.startTime,
    endTime: tc.endTime,
    dayNames: tc.daysOfWeek ?? const [],
    rawExpression: tc.rawExpression,
  );
}

String _format({
  required String type,
  required String? startDate,
  required String? endDate,
  required String? startTime,
  required String? endTime,
  required List<String> dayNames,
  required String? rawExpression,
}) {
  final result = switch (type) {
    ConditionType.datetime => _formatDateTime(startDate, startTime),
    ConditionType.date => _formatDate(startDate),
    ConditionType.dateRange => _formatDateRange(startDate, endDate),
    ConditionType.week => _formatWeek(dayNames, startTime, endTime),
    ConditionType.timeRange => _formatTimeRange(startTime, endTime),
    _ => '',
  };
  if (result.isNotEmpty) return result;
  // 매핑 실패 시 AI 원본 표현 → 그래도 없으면 타입명 fallback
  if (rawExpression != null &&
      rawExpression.trim().isNotEmpty &&
      rawExpression != 'null') {
    return rawExpression;
  }
  return _typeFallback(type);
}

/// 날짜+시간 — "5월 11일 15:00" / 시간 없으면 "5월 11일"
String _formatDateTime(String? date, String? time) {
  final d = _formatDate(date);
  final t = _formatTime(time);
  if (d.isEmpty && t.isEmpty) return '';
  if (t.isEmpty) return d;
  if (d.isEmpty) return t;
  return '$d $t';
}

/// 단일 날짜 — "5월 11일". yyyy-MM-dd가 깨지면 원문 그대로.
String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'null') return '';
  final parts = raw.split('-');
  if (parts.length != 3) return raw;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null) return raw;
  return '$month월 $day일';
}

/// 단일 시간 — "15:00". HH:mm 또는 HH:mm:ss 형태 모두 허용.
String _formatTime(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'null') return '';
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return raw;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// 날짜 범위 — "5월 1일 ~ 5월 10일" / 한쪽만 있으면 "5월 1일부터" "~5월 10일"
String _formatDateRange(String? start, String? end) {
  final s = _formatDate(start);
  final e = _formatDate(end);
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return '~$e';
  if (e.isEmpty) return '$s부터';
  return '$s ~ $e';
}

/// 시간 범위 — "18:00 ~ 20:00" / 한쪽만 있으면 "18:00부터" "~20:00"
String _formatTimeRange(String? start, String? end) {
  final s = _formatTime(start);
  final e = _formatTime(end);
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return '~$e';
  if (e.isEmpty) return '$s부터';
  return '$s ~ $e';
}

/// 요일 반복 — "월·수·금 18:00~20:00" / 평일·주말·매일 그룹화
String _formatWeek(List<String> dayNames, String? startTime, String? endTime) {
  final daysLabel = _formatDays(dayNames);
  final timeLabel = _formatTimeRange(startTime, endTime);
  if (daysLabel.isEmpty && timeLabel.isEmpty) return '';
  if (timeLabel.isEmpty) return daysLabel;
  if (daysLabel.isEmpty) return timeLabel;
  return '$daysLabel $timeLabel';
}

const _dayKo = {
  'MON': '월', 'TUE': '화', 'WED': '수',
  'THU': '목', 'FRI': '금', 'SAT': '토', 'SUN': '일',
};

const _weekdays = {'MON', 'TUE', 'WED', 'THU', 'FRI'};
const _weekend = {'SAT', 'SUN'};

String _formatDays(List<String> days) {
  if (days.isEmpty) return '';
  final set = days.toSet();
  if (set.length == 7) return '매일';
  if (set.length == 5 && set.containsAll(_weekdays)) return '평일';
  if (set.length == 2 && set.containsAll(_weekend)) return '주말';
  // 입력 순서 무시하고 월~일 고정 순서로 정렬
  const order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  final sorted = [for (final d in order) if (set.contains(d)) d];
  return sorted.map((d) => _dayKo[d] ?? d).join('·');
}

String _typeFallback(String type) {
  return switch (type) {
    ConditionType.datetime => '일시 미지정',
    ConditionType.date => '날짜 미지정',
    ConditionType.dateRange => '기간 미지정',
    ConditionType.week => '요일 미지정',
    ConditionType.timeRange => '시간대 미지정',
    _ => '시간 조건',
  };
}
