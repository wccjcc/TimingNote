class GeofenceSlotsResponse {
  const GeofenceSlotsResponse({
    required this.lastCalculatedAt,
    required this.slots,
  });

  final DateTime? lastCalculatedAt;
  final List<GeofenceSlotItem> slots;

  factory GeofenceSlotsResponse.fromJson(Map<String, dynamic> json) {
    return GeofenceSlotsResponse(
      lastCalculatedAt: json['lastCalculatedAt'] == null
          ? null
          : DateTime.tryParse(json['lastCalculatedAt'].toString()),
      slots: (json['slots'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => GeofenceSlotItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class GeofenceSlotItem {
  const GeofenceSlotItem({
    required this.slotId,
    required this.todoId,
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.active,
    required this.calculatedAt,
  });

  final int slotId;
  final int todoId;
  final int placeId;
  final double? latitude;
  final double? longitude;
  final int? radiusM;
  final bool active;
  final DateTime? calculatedAt;

  factory GeofenceSlotItem.fromJson(Map<String, dynamic> json) {
    return GeofenceSlotItem(
      slotId: (json['slotId'] as num?)?.toInt() ?? 0,
      todoId: (json['todoId'] as num?)?.toInt() ?? 0,
      placeId: (json['placeId'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusM: (json['radiusM'] as num?)?.toInt(),
      active: json['active'] == true,
      calculatedAt: json['calculatedAt'] == null
          ? null
          : DateTime.tryParse(json['calculatedAt'].toString()),
    );
  }
}
