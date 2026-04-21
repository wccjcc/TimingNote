import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_provider.dart';
import 'geofence_event.dart';

/// Geofence 이벤트를 백엔드로 전송하는 Publisher
class GeofenceEventPublisher {
  GeofenceEventPublisher(this._apiClient);

  final ApiClient _apiClient;

  Future<void> publish(GeofenceEvent event) async {
    await _apiClient.post<void>(
      ApiEndpoints.geofenceEvents,
      data: event.toJson(),
      dataParser: (_) => null,
    );
  }
}

final geofenceEventPublisherProvider = Provider<GeofenceEventPublisher>((ref) {
  return GeofenceEventPublisher(ref.read(apiClientProvider));
});
