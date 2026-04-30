/// 목록 아이템 모델 + 공통 enum 상수
library;

// ── Enum 상수 ────────────────────────────────────────────────────
// 화면/뷰모델에서 매직 스트링 대신 사용
class TodoStatus {
  static const String active = 'ACTIVE';
  static const String done = 'DONE';
  static const String deleted = 'DELETED';
}

class StructureStatus {
  static const String pending = 'PENDING';
  static const String ready = 'READY';
  static const String failed = 'FAILED';
}

class InputType {
  static const String text = 'TEXT';
  static const String voice = 'VOICE';
  static const String image = 'IMAGE';
  static const String link = 'LINK';
}

class TodoType {
  static const String specific = 'SPECIFIC';
  static const String generic = 'GENERIC';
  static const String alias = 'ALIAS';
  static const String general = 'GENERAL';
}

class TodoCategory {
  static const String dine = 'DINE';
  static const String acquire = 'ACQUIRE';
  static const String health = 'HEALTH';
  static const String service = 'SERVICE';
  static const String maintenance = 'MAINTENANCE';
  static const String social = 'SOCIAL';
  static const String etc = 'ETC';

  static const Map<String, String> labels = {
    dine: '식사/카페',
    acquire: '쇼핑/수령',
    health: '병원/약국/운동',
    service: '은행/관공서/업무',
    maintenance: '세탁/주유/정비',
    social: '모임/방문/선물',
    etc: '기타',
  };
}

// ── TodoItem (목록 항목) ──────────────────────────────────────────
class TodoItem {
  const TodoItem({
    required this.id,
    required this.inputType,
    required this.content,
    required this.todoType,
    required this.status,
    required this.structureStatus,
    required this.alertEnabled,
    required this.createdAt,
    this.category,
    this.resolvedPlaceLabel,
    this.completedAt,
    this.thumbnailUrl,
  });

  final int id;
  final String inputType;
  final String content;
  final String todoType;
  final String status;
  final String structureStatus;
  final String? category;
  final String? resolvedPlaceLabel;
  final bool alertEnabled;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? thumbnailUrl;

  bool get isPending => structureStatus == StructureStatus.pending;
  bool get isDone => status == TodoStatus.done;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as int,
      inputType: json['inputType'] as String,
      content: json['content'] as String,
      todoType: json['todoType'] as String,
      status: json['status'] as String,
      structureStatus: json['structureStatus'] as String,
      category: json['category'] as String?,
      resolvedPlaceLabel: json['resolvedPlaceLabel'] as String?,
      alertEnabled: json['alertEnabled'] as bool,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  TodoItem copyWith({
    bool? alertEnabled,
    String? status,
    DateTime? completedAt,
  }) {
    return TodoItem(
      id: id,
      inputType: inputType,
      content: content,
      todoType: todoType,
      status: status ?? this.status,
      structureStatus: structureStatus,
      category: category,
      resolvedPlaceLabel: resolvedPlaceLabel,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

// ── TodoListResult (목록 API 응답) ────────────────────────────────
class TodoListResult {
  const TodoListResult({
    required this.items,
    this.nextCursor,
  });

  final List<TodoItem> items;
  final int? nextCursor;

  bool get hasMore => nextCursor != null;

  factory TodoListResult.fromJson(Map<String, dynamic> json) {
    return TodoListResult(
      items: (json['items'] as List<dynamic>)
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as int?,
    );
  }
}

// ── TodoCreateResult (생성 API 응답) ──────────────────────────────
class TodoCreateResult {
  const TodoCreateResult({
    required this.todoId,
    required this.status,
    required this.structureStatus,
    required this.createdAt,
  });

  final int todoId;
  final String status;
  final String structureStatus;
  final DateTime createdAt;

  factory TodoCreateResult.fromJson(Map<String, dynamic> json) {
    return TodoCreateResult(
      todoId: json['todoId'] as int,
      status: json['status'] as String,
      structureStatus: json['structureStatus'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
