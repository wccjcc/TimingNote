import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_provider.dart';
import 'notification_permission_service.dart';

const String _lastSyncedFcmTokenKey = 'last_synced_fcm_token';

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
  return NotificationPermissionService();
});

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService(
    apiClient: ref.read(apiClientProvider),
    permissionService: ref.read(notificationPermissionServiceProvider),
  );
});

/// FCM 토큰 초기화 및 서버 동기화를 담당하는 서비스
class FcmTokenService {
  FcmTokenService({
    required ApiClient apiClient,
    required NotificationPermissionService permissionService,
  })  : _apiClient = apiClient,
        _permissionService = permissionService;

  final ApiClient _apiClient;
  final NotificationPermissionService _permissionService;
  final Logger _logger = Logger();

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  FirebaseMessaging? _messaging;

  /// 앱 시작 시 1회 호출해서 Firebase/FCM 초기화와 최초 토큰 등록을 수행한다.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // 현재 요구사항은 모바일 푸시 등록이므로 iOS/Android에서만 동작시킨다.
    if (!_isSupportedPlatform) {
      _logger.i('현재 플랫폼은 FCM 토큰 등록 대상이 아니라 초기화를 건너뜁니다.');
      return;
    }

    // FCM 등록 API는 X-Device-Secret 인증이 필요하므로 먼저 디바이스 등록을 보장한다.
    await _initializeFirebase();
    await _requestNotificationPermission();
    await _syncCurrentToken();
    _listenTokenRefresh();
  }

  /// 로그아웃이나 알림 비활성화 시 서버에 비활성 상태를 전달할 때 사용할 수 있다.
  Future<void> deactivateCurrentToken() async {
    final messaging = _messaging;
    if (messaging == null) {
      _logger.w('Firebase Messaging이 아직 초기화되지 않았습니다.');
      return;
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      _logger.w('비활성화할 FCM 토큰이 없습니다.');
      return;
    }

    await _upsertFcmToken(
      token: token,
      isActive: false,
      forceSync: true,
    );
  }

  Future<void> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      _messaging ??= FirebaseMessaging.instance;
      return;
    }

    await Firebase.initializeApp();
    _messaging = FirebaseMessaging.instance;
  }

  /// 알림 권한은 FCM 토큰 확보 전에 먼저 요청해 두는 편이 흐름상 안전하다.
  Future<void> _requestNotificationPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      throw StateError('Firebase Messaging이 초기화되지 않았습니다.');
    }

    await _permissionService.request();

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// 앱 시작 직후 현재 토큰을 한 번 읽어서 서버와 맞춘다.
  Future<void> _syncCurrentToken() async {
    final messaging = _messaging;
    if (messaging == null) {
      throw StateError('Firebase Messaging이 초기화되지 않았습니다.');
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      _logger.w('현재 FCM 토큰을 아직 발급받지 못했습니다.');
      return;
    }

    await _upsertFcmToken(token: token, isActive: true);
  }

  /// OS 또는 Firebase가 토큰을 재발급하면 즉시 서버에 최신 값으로 갱신한다.
  void _listenTokenRefresh() {
    final messaging = _messaging;
    if (messaging == null) {
      throw StateError('Firebase Messaging이 초기화되지 않았습니다.');
    }

    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
      (token) async {
        if (token.isEmpty) {
          return;
        }

        await _upsertFcmToken(
          token: token,
          isActive: true,
          forceSync: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.e(
          'FCM 토큰 갱신 감지 중 오류가 발생했습니다.',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// 마지막으로 서버에 올린 토큰과 같으면 중복 호출을 줄인다.
  Future<void> _upsertFcmToken({
    required String token,
    required bool isActive,
    bool forceSync = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final lastSyncedToken = preferences.getString(_lastSyncedFcmTokenKey);

    if (!forceSync && isActive && lastSyncedToken == token) {
      _logger.i('이미 서버에 등록된 FCM 토큰이라 재전송을 생략합니다.');
      return;
    }

    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.fcmTokens,
      data: {
        'fcmToken': token,
        'platform': _platformValue,
        'isActive': isActive,
      },
      dataParser: (json) => Map<String, dynamic>.from(json as Map),
    );

    await preferences.setString(_lastSyncedFcmTokenKey, token);
    _logger.i('FCM 토큰 서버 등록 완료: ${response.data}');
  }

  String get _platformValue {
    if (Platform.isIOS) {
      return 'IOS';
    }

    return 'ANDROID';
  }

  bool get _isSupportedPlatform => Platform.isIOS || Platform.isAndroid;
}
