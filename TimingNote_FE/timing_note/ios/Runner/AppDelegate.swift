import Flutter
import UIKit
import KakaoMapsSDK
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// iOS 푸시 액션 카테고리 식별자입니다.
  /// 서버(APNs/FCM payload)의 `category` 값과 동일해야 버튼이 노출됩니다.
  private let geofenceActionCategoryId = "GEOFENCE_TODO_ACTIONS"

  /// 액션 식별자: 할 일 완료
  private let actionComplete = "COMPLETE"

  /// 액션 식별자: 1시간 스누즈
  private let actionSnooze60 = "SNOOZE_60"
  /// Flutter로 푸시 액션 탭 이벤트를 전달하는 채널 이름입니다.
  private let pushActionChannelName = "timing_note/push_actions"
  private var pushActionChannel: FlutterMethodChannel?
  private var pendingPushActionPayloads: [[String: Any]] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Kakao Maps SDK 초기화: Info.plist/xcconfig로 주입된 키를 사용합니다.
    let kakaoKey = resolveKakaoNativeAppKey()
    SDKInitializer.InitSDK(appKey: kakaoKey)

    // Geofence 네이티브 브릿지 준비
    NativeGeofenceBridge.shared.prepare()

    // iOS 알림 액션 카테고리를 앱 시작 시 등록합니다.
    // - 로컬 알림을 쓰지 않더라도, 원격 푸시에서 액션 버튼을 노출하려면
    //   UNUserNotificationCenter에 카테고리가 미리 등록되어 있어야 합니다.
    registerNotificationCategories()

    // foreground 수신/액션 탭 콜백을 받기 위해 delegate를 AppDelegate로 지정합니다.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    NativeGeofenceBridge.shared.attachChannels(pluginRegistry: engineBridge.pluginRegistry)
    registerNativeKakaoMap(pluginRegistry: engineBridge.pluginRegistry)
    attachPushActionChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  /// Flutter의 UiKitView에서 iOS 네이티브 KakaoMapsSDK 지도를 만들 수 있도록 등록합니다.
  ///
  /// Dart 화면은 viewType 문자열만 알고 있고, 실제 지도 UIView 생성은 여기서 연결한
  /// PlatformViewFactory가 담당합니다.
  private func registerNativeKakaoMap(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "TimingNoteNativeKakaoMap") else {
      assertionFailure("TimingNoteNativeKakaoMap registrar is unavailable")
      return
    }

    registrar.register(
      TimingNoteNativeKakaoMapFactory(messenger: registrar.messenger()),
      withId: "timing_note/native_kakao_map"
    )
  }

  /// Kakao Native App Key를 런타임에서 안전하게 찾습니다.
  ///
  /// Flutter의 `--dart-define-from-file=.env` 값은 iOS 빌드 설정에
  /// `DART_DEFINES`라는 base64 목록으로 들어갑니다. 따라서 Info.plist의
  /// `$(KAKAO_NATIVE_APP_KEY)`는 자동 치환되지 않을 수 있어, 먼저 직접 키 값을
  /// 확인하고 없으면 `DART_DEFINES`에서 `KAKAO_NATIVE_APP_KEY=...` 항목만 꺼냅니다.
  private func resolveKakaoNativeAppKey() -> String {
    if let directValue = Bundle.main.infoDictionary?["KAKAO_NATIVE_APP_KEY"] as? String,
       !directValue.isEmpty,
       !directValue.hasPrefix("$(") {
      return directValue
    }

    guard let dartDefines = Bundle.main.infoDictionary?["FLUTTER_DART_DEFINES"] as? String else {
      return ""
    }

    for encodedDefine in dartDefines.split(separator: ",") {
      guard let data = Data(base64Encoded: String(encodedDefine)),
            let decoded = String(data: data, encoding: .utf8) else {
        continue
      }

      let prefix = "KAKAO_NATIVE_APP_KEY="
      if decoded.hasPrefix(prefix) {
        return String(decoded.dropFirst(prefix.count))
      }
    }

    return ""
  }

  /// 푸시 액션 버튼 카테고리를 등록합니다.
  ///
  /// 요구사항:
  /// - 버튼 2개: 완료 / 1시간 후 알림해제
  /// - 액션 후 즉시 닫힘: foreground 옵션을 주지 않아 시스템 기본 동작(즉시 닫힘) 사용
  private func registerNotificationCategories() {
    let completeAction = UNNotificationAction(
      identifier: actionComplete,
      title: "완료",
      options: []
    )

    let snoozeAction = UNNotificationAction(
      identifier: actionSnooze60,
      title: "1시간 후 알림해제",
      options: []
    )

    let geofenceCategory = UNNotificationCategory(
      identifier: geofenceActionCategoryId,
      actions: [completeAction, snoozeAction],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([geofenceCategory])
  }

  /// 앱이 foreground일 때는 시스템 푸시 UI를 표시하지 않습니다.
  /// Flutter(onMessage)에서 인앱 토스트만 노출하도록 위임합니다.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([])
  }

  /// 사용자가 알림 액션 버튼을 눌렀을 때 호출됩니다.
  ///
  /// 현재 단계에서는 카테고리/액션 수신 경로를 확정하는 것이 목표이며,
  /// 실제 COMPLETE/SNOOZE API 호출은 다음 단계에서 Flutter 또는 네이티브 네트워크 계층으로 연결하면 됩니다.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let categoryId = response.notification.request.content.categoryIdentifier
    let actionId = response.actionIdentifier

    if categoryId == geofenceActionCategoryId {
      NSLog("[PushAction] category=\(categoryId), action=\(actionId)")
      forwardPushActionToFlutter(response: response)
    }

    completionHandler()
  }

  /// Flutter MethodChannel을 연결합니다.
  ///
  /// Implicit Flutter Engine이 준비된 시점에만 messenger를 확보할 수 있으므로
  /// didInitializeImplicitFlutterEngine에서 호출합니다.
  private func attachPushActionChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "PushActionBridge") else {
      assertionFailure("PushActionBridge registrar is unavailable")
      return
    }

    pushActionChannel = FlutterMethodChannel(
      name: pushActionChannelName,
      binaryMessenger: registrar.messenger()
    )

    // 엔진 초기화 전에 적재된 액션 이벤트가 있다면 순서대로 전달합니다.
    flushPendingPushActionPayloads()
  }

  /// iOS 알림 액션 탭 응답을 Flutter로 전달합니다.
  ///
  /// 전달 payload:
  /// - actionId: COMPLETE / SNOOZE_60
  /// - notificationId: 백엔드가 data payload로 내려준 notifications PK
  /// - todoId / slotId: 디버깅 및 추적용 보조 정보
  private func forwardPushActionToFlutter(response: UNNotificationResponse) {
    let userInfo = response.notification.request.content.userInfo
    let payload: [String: Any] = [
      "actionId": response.actionIdentifier,
      "notificationId": String(describing: userInfo["notificationId"] ?? ""),
      "todoId": String(describing: userInfo["todoId"] ?? ""),
      "slotId": String(describing: userInfo["slotId"] ?? "")
    ]

    guard let channel = pushActionChannel else {
      pendingPushActionPayloads.append(payload)
      return
    }

    channel.invokeMethod("onPushAction", arguments: payload)
  }

  /// 아직 Flutter 채널이 준비되지 않아 대기 중이던 이벤트를 재전송합니다.
  private func flushPendingPushActionPayloads() {
    guard let channel = pushActionChannel else { return }
    for payload in pendingPushActionPayloads {
      channel.invokeMethod("onPushAction", arguments: payload)
    }
    pendingPushActionPayloads.removeAll()
  }
}

private final class TimingNoteNativeKakaoMapFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return TimingNoteNativeKakaoMapView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private final class TimingNoteNativeKakaoMapView: NSObject, FlutterPlatformView {
  private let container: TimingNoteKakaoMapContainer
  private let controller: KMController
  private let channel: FlutterMethodChannel
  private let mapViewName: String
  private let initialPosition: MapPoint
  private let initialLevel: Int

  private weak var kakaoMap: KakaoMap?
  private var pendingCameraTarget: MapPoint?
  private var lastNativeState = "created"
  private var engineStartRequested = false

  // ── 후보 장소 마커 (GENERIC 디버깅용) ─────────────────────────────────────
  // 지도 엔진이 늦게 준비되는 경우, Flutter 쪽 첫 setMarkers 호출은 여기에 보관했다가
  // addViewSucceeded 직후 applyMarkers로 반영한다.
  private var candidateLayer: LabelLayer?
  private var pendingMarkerPayload: [[String: Any]]?
  private var candidateStylesRegistered = false
  private let candidateLayerID = "timing_note_candidates"
  private let candidateActiveStyleID = "tn_candidate_active"
  private let candidateInactiveStyleID = "tn_candidate_inactive"

  init(
    frame: CGRect,
    viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let params = args as? [String: Any]
    let latitude = params?["latitude"] as? Double ?? 37.5665
    let longitude = params?["longitude"] as? Double ?? 126.9780
    let level = params?["level"] as? Int ?? 15

    self.container = TimingNoteKakaoMapContainer(frame: frame)
    self.controller = KMController(viewContainer: container)
    self.channel = FlutterMethodChannel(
      name: "timing_note/native_kakao_map_\(viewId)",
      binaryMessenger: messenger
    )
    self.mapViewName = "timing_note_map_\(viewId)"
    self.initialPosition = MapPoint(longitude: longitude, latitude: latitude)
    self.initialLevel = level

    super.init()

    container.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
    controller.delegate = self
    container.setDelegate(self)
    container.onLayout = { [weak self] size in
      self?.startEngineIfPossible(reason: "layout size=\(size)")
    }

    // Flutter에서 내려오는 지도 명령을 네이티브 SDK 호출로 변환합니다.
    // 화면이 먼저 좌표 이동을 요청하고 SDK 렌더링이 아직 준비되지 않은 경우에는
    // pendingCameraTarget에 보관했다가 addViewSucceeded 이후 적용합니다.
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }

    DispatchQueue.main.async { [weak self] in
      self?.startEngineIfPossible(reason: "nextRunLoop")
    }
  }

  func view() -> UIView {
    return container
  }

  deinit {
    channel.setMethodCallHandler(nil)
    controller.pauseEngine()
    controller.resetEngine()
  }

  private func handle(call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "debugState":
      result([
        "lastNativeState": lastNativeState,
        "enginePrepared": controller.isEnginePrepared,
        "engineActive": controller.isEngineActive,
        "engineStartRequested": engineStartRequested,
        "bounds": "\(container.bounds)",
        "renderView": String(describing: container.renderView),
        "subviewCount": container.subviews.count,
        "mapReady": kakaoMap != nil,
        "stateDescription": controller.getStateDescMessage(),
      ])
    case "panTo":
      guard let args = call.arguments as? [String: Any],
            let latitude = args["latitude"] as? Double,
            let longitude = args["longitude"] as? Double else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "latitude/longitude is required",
          details: nil
        ))
        return
      }

      moveCamera(to: MapPoint(longitude: longitude, latitude: latitude))
      result(nil)
    case "setMarkers":
      guard let args = call.arguments as? [String: Any],
            let markers = args["markers"] as? [[String: Any]] else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "markers list is required",
          details: nil
        ))
        return
      }

      // 엔진/지도가 아직 준비되지 않았으면 보류 후 addViewSucceeded에서 반영
      if kakaoMap == nil {
        pendingMarkerPayload = markers
      } else {
        applyCandidateMarkers(markers)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 후보 장소 마커들을 LabelLayer에 다시 그린다.
  /// 동일 layerID/styleID는 재사용하고, 이전 마커는 clearAllItems로 모두 제거 후 새로 등록한다.
  private func applyCandidateMarkers(_ markers: [[String: Any]]) {
    guard let map = kakaoMap else { return }
    let manager = map.getLabelManager()
    registerCandidateStylesIfNeeded(manager: manager)
    let layer = ensureCandidateLayer(manager: manager)
    layer?.clearAllItems()

    for (index, marker) in markers.enumerated() {
      guard let lat = marker["latitude"] as? Double,
            let lng = marker["longitude"] as? Double,
            let id = marker["id"] as? String else {
        continue
      }
      let active = (marker["active"] as? Bool) ?? false
      let styleID = active ? candidateActiveStyleID : candidateInactiveStyleID
      let options = PoiOptions(styleID: styleID, poiID: id)
      // rank: 활성 후보가 더 높은 우선순위를 가져 위에 그려지도록 조정
      options.rank = active ? index : index + 1000
      options.clickable = true // 사용자가 마커를 탭하면 Flutter에 poiId 전달
      let point = MapPoint(longitude: lng, latitude: lat)
      let poi = layer?.addPoi(option: options, at: point)
      // Poi 단위로 tap handler 등록 — handler에서 itemID(=Flutter에서 전달한 id) 회수해 채널 전송.
      _ = poi?.addPoiTappedEventHandler(
        target: self,
        handler: TimingNoteNativeKakaoMapView.handlePoiTapped
      )
      poi?.show()
    }
  }

  /// 마커 탭 이벤트 → Flutter "onPoiTapped" 호출. id는 setMarkers 시 전달했던 문자열.
  private func handlePoiTapped(_ param: PoiInteractionEventParam) {
    let poiId = param.poiItem.itemID
    channel.invokeMethod("onPoiTapped", arguments: ["id": poiId])
  }

  /// LabelLayer를 1회만 생성하고 캐시한다. 같은 layerID가 이미 등록돼 있으면 그대로 재사용.
  private func ensureCandidateLayer(manager: LabelManager) -> LabelLayer? {
    if let existing = candidateLayer { return existing }
    let option = LabelLayerOptions(
      layerID: candidateLayerID,
      competitionType: .none,
      competitionUnit: .symbolFirst,
      orderType: .rank,
      zOrder: 5000
    )
    let layer = manager.addLabelLayer(option: option)
    candidateLayer = layer
    return layer
  }

  /// 활성/비활성 마커 PoiStyle을 1회만 등록한다.
  /// 아이콘은 UIGraphicsImageRenderer로 동적 생성 (외부 에셋 의존 제거).
  private func registerCandidateStylesIfNeeded(manager: LabelManager) {
    if candidateStylesRegistered { return }

    if let image = makeMarkerImage(color: UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)) {
      let iconStyle = PoiIconStyle(symbol: image)
      let perLevel = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
      manager.addPoiStyle(PoiStyle(styleID: candidateActiveStyleID, styles: [perLevel]))
    }
    if let image = makeMarkerImage(color: UIColor(white: 0.6, alpha: 0.85)) {
      let iconStyle = PoiIconStyle(symbol: image)
      let perLevel = PerLevelPoiStyle(iconStyle: iconStyle, level: 0)
      manager.addPoiStyle(PoiStyle(styleID: candidateInactiveStyleID, styles: [perLevel]))
    }
    candidateStylesRegistered = true
  }

  /// Material `Icons.location_on` 스타일 핀 마커를 그린다.
  /// 위쪽 둥근 머리 + 아래쪽 뾰족한 꼬리 + 안쪽 흰 highlight (물방울 형태).
  /// place_search_screen의 Flutter 위젯 오버레이(Icons.location_on)와 톤 통일.
  private func makeMarkerImage(color: UIColor) -> UIImage? {
    let size = CGSize(width: 28, height: 36)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
      let cg = ctx.cgContext

      // 머리 + 꼬리를 한 path로 합쳐서 한 번에 fill — 경계 안티앨리어싱 자국 방지.
      let headCenter = CGPoint(x: size.width / 2, y: 13)
      let headRadius: CGFloat = 11
      let tailTipY = size.height - 2
      // 머리 양옆 접선 각도 (수평선 기준 약 30° 아래) — 꼬리가 자연스럽게 이어지는 폭.
      let tangentAngle: CGFloat = .pi / 6   // 30°
      let rightTangent = CGPoint(
        x: headCenter.x + headRadius * cos(tangentAngle),
        y: headCenter.y + headRadius * sin(tangentAngle)
      )
      let leftTangent = CGPoint(
        x: headCenter.x - headRadius * cos(tangentAngle),
        y: headCenter.y + headRadius * sin(tangentAngle)
      )

      let path = UIBezierPath()
      // 오른쪽 접점 → 꼬리 끝 → 왼쪽 접점
      path.move(to: rightTangent)
      path.addLine(to: CGPoint(x: headCenter.x, y: tailTipY))
      path.addLine(to: leftTangent)
      // 왼쪽 접점 → 위쪽 호 → 오른쪽 접점.
      // UIKit 좌표(y 아래 양수)에서 angle 양수가 시계방향이라 clockwise=true가
      // 150°→180°→270°→0°→30° 경로로 머리 위쪽을 돌아간다.
      path.addArc(
        withCenter: headCenter,
        radius: headRadius,
        startAngle: .pi - tangentAngle,    // 왼 접점 각도 (180° - 30° = 150°)
        endAngle: tangentAngle,            // 오른 접점 각도 (30°)
        clockwise: true                    // 위쪽으로 호
      )
      path.close()

      cg.setFillColor(color.cgColor)
      cg.addPath(path.cgPath)
      cg.fillPath()

      // 흰 테두리 (얇게)
      cg.setStrokeColor(UIColor.white.cgColor)
      cg.setLineWidth(1.5)
      cg.addPath(path.cgPath)
      cg.strokePath()

      // 안쪽 흰 highlight (Material location_on의 작은 원 부분)
      let innerRadius: CGFloat = 4
      let innerRect = CGRect(
        x: headCenter.x - innerRadius,
        y: headCenter.y - innerRadius,
        width: innerRadius * 2,
        height: innerRadius * 2
      )
      cg.setFillColor(UIColor.white.cgColor)
      cg.fillEllipse(in: innerRect)
    }
  }

  private func startEngineIfPossible(reason: String) {
    guard !engineStartRequested else { return }

    let size = container.bounds.size
    guard size.width > 0 && size.height > 0 else {
      lastNativeState = "waitingForLayout"
      return
    }

    engineStartRequested = true
    let prepared = controller.prepareEngine()
    lastNativeState = prepared ? "prepareEngineSucceeded" : "prepareEngineFailed"

    if prepared {
      controller.activateEngine()
    }
  }

  private func moveCamera(to target: MapPoint) {
    guard let map = kakaoMap else {
      pendingCameraTarget = target
      return
    }

    let update = CameraUpdate.make(target: target, zoomLevel: map.zoomLevel, mapView: map)
    map.moveCamera(update)
  }

  private func notifyCameraIdle(from map: KakaoMap) {
    let centerPoint = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
    let coordinate = map.getPosition(centerPoint).wgsCoord

    channel.invokeMethod("onCameraIdle", arguments: [
      "latitude": coordinate.latitude,
      "longitude": coordinate.longitude,
      "level": map.zoomLevel,
    ])
  }
}

extension TimingNoteNativeKakaoMapView: MapControllerDelegate {
  func addViews() {
    lastNativeState = "addViews"
    let mapInfo = MapviewInfo(
      viewName: mapViewName,
      appName: "openmap",
      viewInfoName: "map",
      defaultPosition: initialPosition,
      defaultLevel: initialLevel,
      enabled: true
    )

    // PlatformView가 생성되는 아주 이른 시점에는 bounds가 아직 0일 수 있습니다.
    // 이 경우 SDK가 빈 크기의 지도를 만들지 않도록 화면 크기를 임시 기본값으로 사용합니다.
    let currentSize = container.bounds.size
    let fallbackSize = UIScreen.main.bounds.size
    let viewSize: CGSize
    if currentSize.width > 0 && currentSize.height > 0 {
      viewSize = currentSize
    } else {
      viewSize = fallbackSize
    }

    controller.addView(mapInfo, viewSize: viewSize)
  }

  func addViewSucceeded(_ viewName: String, viewInfoName: String) {
    guard let map = controller.getView(viewName) as? KakaoMap else { return }
    lastNativeState = "addViewSucceeded"
    kakaoMap = map
    map.eventDelegate = self

    if let target = pendingCameraTarget {
      pendingCameraTarget = nil
      moveCamera(to: target)
    } else {
      notifyCameraIdle(from: map)
    }

    // Flutter가 엔진 준비 전에 setMarkers를 호출한 경우 여기서 반영
    if let payload = pendingMarkerPayload {
      pendingMarkerPayload = nil
      applyCandidateMarkers(payload)
    }
  }

  func addViewFailed(_ viewName: String, viewInfoName: String) {
    lastNativeState = "addViewFailed"
  }

  func authenticationFailed(_ errorCode: Int, desc: String) {
    lastNativeState = "authenticationFailed"
  }

  func authenticationSucceeded() {
    lastNativeState = "authenticationSucceeded"
  }

  func containerDidResized(_ size: CGSize) {
  }
}

extension TimingNoteNativeKakaoMapView: KakaoMapEventDelegate {
  func cameraWillMove(kakaoMap: KakaoMap, by: MoveBy) {
    channel.invokeMethod("onCameraMoveStarted", arguments: nil)
  }

  func cameraDidStopped(kakaoMap: KakaoMap, by: MoveBy) {
    notifyCameraIdle(from: kakaoMap)
  }
}

extension TimingNoteNativeKakaoMapView: K3fMapContainerDelegate {}

private final class TimingNoteKakaoMapContainer: KMViewContainer {
  var onLayout: ((CGSize) -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?(bounds.size)
  }
}
