class NotificationItem {
  NotificationItem({
    required this.id,
    required this.notificationType,
    required this.status,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.openedAt,
    this.todoId,
    this.userId,
  });

  final int id;
  final int? userId;
  final int? todoId;
  final String notificationType;
  final String status;
  final String? title;
  final String? body;
  final DateTime? createdAt;
  final DateTime? openedAt;

  bool get isUnread => status != 'OPENED';

  NotificationItem copyWith({
    String? status,
    DateTime? openedAt,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      todoId: todoId,
      notificationType: notificationType,
      status: status ?? this.status,
      title: title,
      body: body,
      createdAt: createdAt,
      openedAt: openedAt ?? this.openedAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      todoId: (json['todoId'] as num?)?.toInt(),
      notificationType: (json['notificationType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      title: json['title'] as String?,
      body: json['body'] as String?,
      createdAt: _parseDate(json['createdAt']),
      openedAt: _parseDate(json['openedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class NotificationPage {
  NotificationPage({
    required this.content,
    required this.totalElements,
    required this.page,
    required this.size,
  });

  final List<NotificationItem> content;
  final int totalElements;
  final int page;
  final int size;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final contentJson = (json['content'] as List<dynamic>? ?? const []);
    return NotificationPage(
      content: contentJson
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
    );
  }
}

class NotificationActionResult {
  NotificationActionResult({
    required this.actionType,
    this.todoStatus,
    this.snoozedUntil,
  });

  final String actionType;
  final String? todoStatus;
  final DateTime? snoozedUntil;

  factory NotificationActionResult.fromJson(Map<String, dynamic> json) {
    return NotificationActionResult(
      actionType: (json['actionType'] ?? '').toString(),
      todoStatus: json['todoStatus'] as String?,
      snoozedUntil: NotificationItem._parseDate(json['snoozedUntil']),
    );
  }
}

