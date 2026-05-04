/// 시간 조건 모델
/// - TimeCondition: GET 응답 (daysOfWeek = 비트마스크 int)
/// - TimeConditionRequest: PATCH 요청 (daysOfWeek = ['MON', 'WED', ...])
library;

// ── ConditionType 상수 ────────────────────────────────────────────
class ConditionType {
  static const String datetime = 'DATETIME';   // 날짜+시간
  static const String date = 'DATE';           // 날짜만
  static const String dateRange = 'DATE_RANGE'; // 기간
  static const String week = 'WEEK';           // 요일 반복
  static const String timeRange = 'TIME_RANGE'; // 시간대만
}

// ── 요일 비트마스크 디코더 ─────────────────────────────────────────
// BE 저장 규칙: MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64
const _dayBits = {
  'MON': 1, 'TUE': 2, 'WED': 4,
  'THU': 8, 'FRI': 16, 'SAT': 32, 'SUN': 64,
};

/// 비트마스크 → 요일 문자열 리스트 ['MON', 'WED', ...]
List<String> decodeWeekBitmask(int? mask) {
  if (mask == null || mask == 0) return [];
  return _dayBits.entries
      .where((e) => mask & e.value != 0)
      .map((e) => e.key)
      .toList();
}

/// 요일 리스트 → 비트마스크 (요청 생성 시 사용)
int encodeWeekBitmask(List<String> days) {
  return days.fold(0, (acc, day) => acc | (_dayBits[day] ?? 0));
}

// ── TimeCondition (응답 모델) ─────────────────────────────────────
class TimeCondition {
  const TimeCondition({
    required this.conditionType,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.daysOfWeek,
    this.rawExpression,
  });

  final String conditionType;
  final String? startDate;    // yyyy-MM-dd
  final String? endDate;
  final String? startTime;    // HH:mm
  final String? endTime;
  final int? daysOfWeek;      // 비트마스크
  final String? rawExpression;

  /// 비트마스크를 요일 리스트로 변환
  List<String> get dayNames => decodeWeekBitmask(daysOfWeek);

  factory TimeCondition.fromJson(Map<String, dynamic> json) {
    return TimeCondition(
      conditionType: json['conditionType'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      daysOfWeek: json['daysOfWeek'] as int?,
      rawExpression: json['rawExpression'] as String?,
    );
  }
}

// ── TimeConditionRequest (수정 요청 모델) ─────────────────────────
class TimeConditionRequest {
  const TimeConditionRequest({
    required this.conditionType,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.daysOfWeek,
    this.rawExpression,
  });

  final String conditionType;
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final List<String>? daysOfWeek; // BE 요청은 문자열 리스트
  final String? rawExpression;

  Map<String, dynamic> toJson() {
    return {
      'conditionType': conditionType,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (rawExpression != null) 'rawExpression': rawExpression,
    };
  }

  /// TimeCondition(응답)에서 요청 객체로 변환 (수정 폼 초기값 설정 시)
  factory TimeConditionRequest.fromCondition(TimeCondition tc) {
    return TimeConditionRequest(
      conditionType: tc.conditionType,
      startDate: tc.startDate,
      endDate: tc.endDate,
      startTime: tc.startTime,
      endTime: tc.endTime,
      daysOfWeek: tc.dayNames.isEmpty ? null : tc.dayNames,
      rawExpression: tc.rawExpression,
    );
  }
}
