/// 할 일 검색 결과 한 항목.
///
/// BE 응답 (`GET /api/v1/todos/search`)의 `data.items[*]`에 1:1 대응.
/// BE가 7개 필드만 내려보내도록 슬림화되어 있다.
class TodoSearchItem {
  const TodoSearchItem({
    required this.id,
    required this.content,
    required this.highlights,
    required this.todoType,
    required this.status,
    this.category,
    this.resolvedPlaceLabel,
  });

  final int id;
  final String content;

  /// 필드별 하이라이팅. e.g. `{"content": ["…<em>내일</em> 강남역…"]}`
  /// 매칭이 없는 필드는 키 자체가 없을 수 있다.
  final Map<String, List<String>> highlights;

  final String todoType; // SPECIFIC | GENERIC | ALIAS | GENERAL
  final String status;   // ACTIVE | DONE
  final String? category;
  final String? resolvedPlaceLabel;

  /// content 필드의 첫 번째 highlight fragment. 없으면 원문 content.
  /// UI에서 `<em>` 마커를 굵게 렌더링할 때 사용.
  String get contentHighlight {
    final list = highlights['content'];
    if (list != null && list.isNotEmpty) return list.first;
    return content;
  }

  bool get isDone => status == 'DONE';

  factory TodoSearchItem.fromJson(Map<String, dynamic> json) {
    final raw = json['highlights'];
    final hl = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) {
          hl[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    return TodoSearchItem(
      id: json['id'] as int,
      content: json['content']?.toString() ?? '',
      highlights: hl,
      todoType: json['todoType']?.toString() ?? 'GENERAL',
      status: json['status']?.toString() ?? 'ACTIVE',
      category: json['category']?.toString(),
      resolvedPlaceLabel: json['resolvedPlaceLabel']?.toString(),
    );
  }
}

/// 검색 응답 페이지.
class TodoSearchResult {
  const TodoSearchResult({
    required this.items,
    this.nextCursor,
    required this.total,
  });

  final List<TodoSearchItem> items;

  /// 다음 페이지 커서. null이면 마지막 페이지.
  final String? nextCursor;

  /// 총 매칭 수 (track_total_hits 한도 내).
  final int total;

  factory TodoSearchResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? const [];
    return TodoSearchResult(
      items: list
          .map((e) => TodoSearchItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
