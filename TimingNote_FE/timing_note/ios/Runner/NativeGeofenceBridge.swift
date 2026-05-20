import CoreLocation
import Flutter
import Foundation

/// iOS 네이티브 geofence 브리지
///
/// 역할
/// 1) Flutter MethodChannel 요청으로 geofence 등록/해제
/// 2) iOS CoreLocation delegate 콜백(enter/exit) 수신
/// 3) EventChannel로 Flutter에 실시간 전달
/// 4) Flutter가 꺼져 있던 동안 수신한 이벤트는 UserDefaults에 임시 저장 후 재전달
final class NativeGeofenceBridge: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {
  static let shared = NativeGeofenceBridge()

  private override init() {
    super.init()
    locationManager.delegate = self
    // 백그라운드 위치 업데이트 허용(Info.plist + Capability도 함께 필요)
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
  }

  private let methodChannelName = "timing_note/geofence_method"
  private let eventChannelName = "timing_note/geofence_events"
  private let pendingEventsKey = "timing_note_geofence_pending_events"
  private let significantChangeGeofenceId = "significant_change"

  private let locationManager = CLLocationManager()
  private let isoFormatter = ISO8601DateFormatter()

  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?

  /// 앱 시작 시점 초기 준비
  func prepare() {
    // delegate 연결은 init에서 완료되어 있고,
    // 여기서는 필요 시 초기화 확장 지점으로 남겨둡니다.
  }

  /// Flutter 엔진이 준비되었을 때 채널 연결
  func attachChannels(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "NativeGeofenceBridge") else {
      assertionFailure("NativeGeofenceBridge registrar is unavailable")
      return
    }

    methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )

    eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )

    methodChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    eventChannel?.setStreamHandler(self)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "registerGeofences":
      registerGeofences(call.arguments, result: result)
    case "clearGeofences":
      clearGeofences(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func registerGeofences(_ arguments: Any?, result: @escaping FlutterResult) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      result(
        FlutterError(
          code: "GEOFENCE_UNAVAILABLE",
          message: "이 기기에서는 geofence 모니터링을 지원하지 않습니다.",
          details: nil
        )
      )
      return
    }

    // 항상 허용 권한이 없다면 요청 후 실패로 반환(사용자 승인 후 다시 호출)
    if !isAlwaysAuthorized() {
      locationManager.requestAlwaysAuthorization()
      result(
        FlutterError(
          code: "LOCATION_ALWAYS_PERMISSION_REQUIRED",
          message: "항상 허용 위치 권한이 필요합니다. 권한 승인 후 다시 시도하세요.",
          details: nil
        )
      )
      return
    }

    guard
      let payload = arguments as? [String: Any],
      let rawRegions = payload["regions"] as? [[String: Any]],
      !rawRegions.isEmpty
    else {
      result(
        FlutterError(
          code: "GEOFENCE_EMPTY",
          message: "등록할 geofence 목록이 비어 있습니다.",
          details: nil
        )
      )
      return
    }

    // 기존 등록을 먼저 정리하고 새 목록으로 교체
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }

    for raw in rawRegions {
      guard
        let id = raw["id"] as? String,
        let lat = raw["latitude"] as? CLLocationDegrees,
        let lng = raw["longitude"] as? CLLocationDegrees,
        let radius = raw["radius"] as? CLLocationDistance
      else {
        continue
      }

      let circular = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        radius: radius,
        identifier: id
      )
      circular.notifyOnEntry = true
      circular.notifyOnExit = true
      locationManager.startMonitoring(for: circular)
    }

    // iOS 유의미한 위치 변화 서비스 시작:
    // - 백그라운드에서도 큰 위치 변화 시 didUpdateLocations 콜백을 받습니다.
    // - geofence enter/exit 누락 보완 및 /geofence/recalculate 트리거 용도로 사용합니다.
    locationManager.startMonitoringSignificantLocationChanges()

    result(nil)
  }

  private func clearGeofences(result: @escaping FlutterResult) {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
    // geofence 감시를 정리할 때 유의미한 위치 변화 감시도 함께 중단합니다.
    locationManager.stopMonitoringSignificantLocationChanges()
    result(nil)
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingEvents()
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    emitTransition(transition: "ENTER", region: region, location: manager.location)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    emitTransition(transition: "EXIT", region: region, location: manager.location)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let latest = locations.last else { return }
    // 너무 오래된 캐시 위치는 재계산 호출 노이즈가 되므로 건너뜁니다.
    let age = Date().timeIntervalSince(latest.timestamp)
    if age > 300 {
      return
    }

    let now = Date()
    let eventId = "\(significantChangeGeofenceId)_SIGNIFICANT_CHANGE_\(Int(now.timeIntervalSince1970 * 1000))"
    var payload: [String: Any] = [
      "eventId": eventId,
      "geofenceId": significantChangeGeofenceId,
      "transition": "SIGNIFICANT_CHANGE",
      "occurredAt": isoFormatter.string(from: now),
      "latitude": latest.coordinate.latitude,
      "longitude": latest.coordinate.longitude,
      "accuracyMeters": latest.horizontalAccuracy,
    ]
    if latest.course >= 0 {
      payload["course"] = latest.course
    }

    appendPendingEvent(payload)

    if let sink = eventSink {
      sink(payload)
      removePendingEvent(eventId: eventId)
    }
  }

  private func emitTransition(transition: String, region: CLRegion, location: CLLocation?) {
    let now = Date()
    let eventId = "\(region.identifier)_\(transition)_\(Int(now.timeIntervalSince1970 * 1000))"

    var payload: [String: Any] = [
      "eventId": eventId,
      "geofenceId": region.identifier,
      "transition": transition,
      "occurredAt": isoFormatter.string(from: now),
      "latitude": location?.coordinate.latitude ?? 0,
      "longitude": location?.coordinate.longitude ?? 0,
    ]

    if let accuracy = location?.horizontalAccuracy {
      payload["accuracyMeters"] = accuracy
    }

    appendPendingEvent(payload)

    if let sink = eventSink {
      sink(payload)
      removePendingEvent(eventId: eventId)
    }
  }

  // MARK: - Pending Event Storage

  private func appendPendingEvent(_ event: [String: Any]) {
    var current = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []
    current.append(event)
    UserDefaults.standard.set(current, forKey: pendingEventsKey)
  }

  private func flushPendingEvents() {
    guard let sink = eventSink else { return }
    let current = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []

    for item in current {
      sink(item)
    }

    UserDefaults.standard.set([], forKey: pendingEventsKey)
  }

  private func removePendingEvent(eventId: String) {
    var current = UserDefaults.standard.array(forKey: pendingEventsKey) as? [[String: Any]] ?? []
    current.removeAll { item in
      (item["eventId"] as? String) == eventId
    }
    UserDefaults.standard.set(current, forKey: pendingEventsKey)
  }

  private func isAlwaysAuthorized() -> Bool {
    let status = locationManager.authorizationStatus
    return status == .authorizedAlways
  }
}
