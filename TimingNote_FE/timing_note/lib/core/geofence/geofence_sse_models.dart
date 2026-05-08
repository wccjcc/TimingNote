enum GeofenceSseConnectionState {
  disconnected,
  connecting,
  connected,
  retrying,
}

class GeofenceSseStatus {
  const GeofenceSseStatus({
    required this.state,
    this.attempt = 0,
    this.reason,
  });

  final GeofenceSseConnectionState state;
  final int attempt;
  final String? reason;
}

class GeofenceSseSignal {
  const GeofenceSseSignal({
    required this.event,
    this.data,
    this.id,
  });

  final String event;
  final String? data;
  final String? id;
}
