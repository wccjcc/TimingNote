/// geofence transition(진입/이탈) 종류입니다.
///
/// 백엔드에는 보통 ENTER/EXIT 문자열로 전달하게 되므로,
/// `toJson()`에서 enum 이름을 대문자로 변환해 보냅니다.
enum GeofenceTransitionType {
  enter,
  exit,
  significantChange,
}

/// 백엔드로 publish할 geofence 이벤트 모델입니다.
///
/// 필드 설명
/// - eventId: 중복 전송 방지를 위한 이벤트 고유 ID(멱등 처리 키)
/// - geofenceId: 어느 geofence에서 발생한 이벤트인지 식별
/// - transition: enter / exit
/// - occurredAt: 이벤트 발생 시각(UTC로 변환하여 전송)
/// - latitude/longitude: 이벤트 발생 시점의 좌표
/// - accuracyMeters: 좌표 정확도(있을 때만 전송)
class GeofenceEvent {
  final String eventId;
  final String geofenceId;
  final GeofenceTransitionType transition;
  final DateTime occurredAt;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  const GeofenceEvent({
    required this.eventId,
    required this.geofenceId,
    required this.transition,
    required this.occurredAt,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  /// API 전송용 JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'geofenceId': geofenceId,
      'transition': transition.name.toUpperCase(),
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    };
  }
}
