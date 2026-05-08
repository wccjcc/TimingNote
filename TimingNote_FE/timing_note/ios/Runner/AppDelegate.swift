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
    let kakaoKey = Bundle.main.infoDictionary?["KAKAO_NATIVE_APP_KEY"] as? String ?? ""
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
    attachPushActionChannel(pluginRegistry: engineBridge.pluginRegistry)
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
      hiddenPreviewsBodyPlaceholder: nil,
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([geofenceCategory])
  }

  /// 앱이 foreground일 때도 푸시 배너/소리를 그대로 보여주도록 설정합니다.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
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
