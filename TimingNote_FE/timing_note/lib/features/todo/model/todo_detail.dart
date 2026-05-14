/// 상세 페이지 모델
/// GET /api/v1/todos/{id} 응답 전체를 담는다.
library;

import 'time_condition.dart';

// ── TodoStructure (AI 구조화 결과) ────────────────────────────────
class TodoStructure {
  const TodoStructure({
    this.todoText,
    this.placeText,
    this.placeType,
    this.timeHintText,
  });

  final String? todoText;
  final String? placeText;
  final String? placeType;
  final String? timeHintText;

  factory TodoStructure.fromJson(Map<String, dynamic> json) {
    return TodoStructure(
      todoText: json['todoText'] as String?,
      placeText: json['placeText'] as String?,
      placeType: json['placeType'] as String?,
      timeHintText: json['timeHintText'] as String?,
    );
  }
}

// ── TodoPlace (연결된 장소 정보) ──────────────────────────────────
class TodoPlace {
  const TodoPlace({
    required this.id,
    this.externalPlaceId,
    required this.name,
    this.address,
    this.roadAddress,
    this.phone,
    this.categoryGroupCode,
    this.categoryGroupName,
    this.businessStatus,
    this.placeUrl,
    this.latitude,
    this.longitude,
  });

  final int id;
  /// 카카오 장소 ID — 후보를 SPECIFIC으로 지정할 때 setExternalPlace 호출에 사용.
  /// 지도 핀(외부 ID 없음)은 null.
  final String? externalPlaceId;
  final String name;
  final String? address;
  final String? roadAddress;
  final String? phone;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final String? businessStatus;   // OPERATIONAL | CLOSED_TEMPORARILY | CLOSED_PERMANENTLY
  final String? placeUrl;
  final double? latitude;
  final double? longitude;

  factory TodoPlace.fromJson(Map<String, dynamic> json) {
    return TodoPlace(
      id: json['id'] as int,
      externalPlaceId: json['externalPlaceId'] as String?,
      name: json['name'] as String,
      address: json['address'] as String?,
      roadAddress: json['roadAddress'] as String?,
      phone: json['phone'] as String?,
      categoryGroupCode: json['categoryGroupCode'] as String?,
      categoryGroupName: json['categoryGroupName'] as String?,
      businessStatus: json['businessStatus'] as String?,
      placeUrl: json['placeUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

// ── TodoCandidate (후보 장소) ─────────────────────────────────────
/// 카카오 로컬 검색으로 매핑된 후보 장소.
/// 사용자 가시성 + 알림 디버깅 용도로 상세 화면에 노출된다.
/// (todoType이 SPECIFIC/ALIAS여도 DB에 후보 잔여가 있으면 응답에 포함됨)
class TodoCandidate {
  const TodoCandidate({
    required this.candidateId,
    required this.place,
    required this.distanceM,
    required this.monitoringTarget,
    required this.activeSlot,
    required this.calculatedAt,
    this.expiresAt,
  });

  final int candidateId;
  final TodoPlace place;
  final int distanceM;
  // 지오펜스 등록 대상 여부 (사용자 명시 제외 등에 사용 — 슬롯 활성 여부와는 다른 축)
  final bool monitoringTarget;
  // 현재 geofence_slots에 활성 등록되어 있는지 (= 알림 트리거 후보)
  final bool activeSlot;
  final DateTime calculatedAt;
  final DateTime? expiresAt;        // null = 유효

  factory TodoCandidate.fromJson(Map<String, dynamic> json) {
    return TodoCandidate(
      candidateId: json['candidateId'] as int,
      place: TodoPlace.fromJson(json['place'] as Map<String, dynamic>),
      distanceM: json['distanceM'] as int,
      monitoringTarget: json['monitoringTarget'] as bool,
      activeSlot: json['activeSlot'] as bool,
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );
  }
}

// ── TodoDetail (상세 전체) ────────────────────────────────────────
class TodoDetail {
  const TodoDetail({
    required this.id,
    required this.content,
    required this.inputType,
    required this.todoType,
    required this.status,
    required this.structureStatus,
    required this.alertEnabled,
    required this.timeConditions,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.candidates,
    this.category,
    this.resolvedPlaceLabel,
    this.snoozedUntil,
    this.completedAt,
    this.structure,
    this.primaryPlace,
    this.sharedUrl,
  });

  final int id;
  final String content;
  final String inputType;
  final String todoType;
  final String status;
  final String structureStatus;
  final String? category;
  final String? resolvedPlaceLabel;
  final bool alertEnabled;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TodoStructure? structure;
  final List<TimeCondition> timeConditions;
  final TodoPlace? primaryPlace;
  final List<String> imageUrls;
  final String? sharedUrl;
  final List<TodoCandidate> candidates;

  bool get isPending => structureStatus == 'PENDING';
  bool get isDone => status == 'DONE';

  factory TodoDetail.fromJson(Map<String, dynamic> json) {
    return TodoDetail(
      id: json['id'] as int,
      content: json['content'] as String,
      inputType: json['inputType'] as String,
      todoType: json['todoType'] as String,
      status: json['status'] as String,
      structureStatus: json['structureStatus'] as String,
      category: json['category'] as String?,
      resolvedPlaceLabel: json['resolvedPlaceLabel'] as String?,
      alertEnabled: json['alertEnabled'] as bool,
      snoozedUntil: json['snoozedUntil'] == null
          ? null
          : DateTime.parse(json['snoozedUntil'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      structure: json['structure'] == null
          ? null
          : TodoStructure.fromJson(json['structure'] as Map<String, dynamic>),
      timeConditions: (json['timeConditions'] as List<dynamic>)
          .map((e) => TimeCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      primaryPlace: json['primaryPlace'] == null
          ? null
          : TodoPlace.fromJson(json['primaryPlace'] as Map<String, dynamic>),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sharedUrl: json['sharedUrl'] as String?,
      candidates: (json['candidates'] as List<dynamic>?)
              ?.map((e) => TodoCandidate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  TodoDetail copyWith({
    bool? alertEnabled,
    String? status,
    DateTime? completedAt,
    List<String>? imageUrls,
  }) {
    return TodoDetail(
      id: id,
      content: content,
      inputType: inputType,
      todoType: todoType,
      status: status ?? this.status,
      structureStatus: structureStatus,
      category: category,
      resolvedPlaceLabel: resolvedPlaceLabel,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      snoozedUntil: snoozedUntil,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      structure: structure,
      timeConditions: timeConditions,
      primaryPlace: primaryPlace,
      imageUrls: imageUrls ?? this.imageUrls,
      sharedUrl: sharedUrl,
      candidates: candidates,
    );
  }
}
