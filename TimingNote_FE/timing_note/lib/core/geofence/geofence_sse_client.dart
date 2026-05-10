import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../network/api_endpoints.dart';
import '../network/api_provider.dart';
import '../storage/device_identity_store.dart';
import 'geofence_sse_models.dart';
import 'geofence_sse_parser.dart';
import 'geofence_sse_policy.dart';

/// Geofence SSE 연결을 관리하는 클라이언트입니다.
///
/// 역할:
/// - 서버 SSE 스트림 연결/해제
/// - 인증 헤더(X-Device-Secret) 주입
/// - 연결 상태 발행(connecting/connected/retrying/disconnected)
/// - 유휴 타임아웃 감시 및 재연결
class GeofenceSseClient {
  GeofenceSseClient({
    required String baseUrl,
    required Future<String?> Function() readDeviceSecret,
    GeofenceSseParser? parser,
    GeofenceSsePolicy? policy,
  }) : _readDeviceSecret = readDeviceSecret,
       _parser = parser ?? GeofenceSseParser(),
       _policy = policy ?? GeofenceSsePolicy(),
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(minutes: 10),
           sendTimeout: const Duration(seconds: 10),
         ),
       );

  final Future<String?> Function() _readDeviceSecret;
  final GeofenceSseParser _parser;
  final GeofenceSsePolicy _policy;
  final Dio _dio;
  final Logger _logger = Logger();

  final StreamController<GeofenceSseSignal> _signalController =
      StreamController<GeofenceSseSignal>.broadcast();
  final StreamController<GeofenceSseStatus> _statusController =
      StreamController<GeofenceSseStatus>.broadcast();

  StreamSubscription<GeofenceSseSignal>? _signalSubscription;
  Timer? _reconnectTimer;
  Timer? _idleTimer;

  bool _running = false;
  bool _closed = false;
  int _retryAttempt = 0;

  Stream<GeofenceSseSignal> get signals => _signalController.stream;
  Stream<GeofenceSseStatus> get statuses => _statusController.stream;

  /// 외부에서 SSE 감시를 시작할 때 호출합니다.
  /// 이미 실행 중이면 중복 연결을 막습니다.
  Future<void> start() async {
    if (_closed || _running) {
      return;
    }
    _running = true;
    _retryAttempt = 0;
    await _connect();
  }

  /// 외부에서 SSE 감시를 멈출 때 호출합니다.
  /// 타이머/구독/소켓을 함께 정리해 백그라운드 누수를 막습니다.
  Future<void> stop() async {
    _running = false;
    _retryAttempt = 0;
    _setStatus(GeofenceSseConnectionState.disconnected, reason: 'stopped');
    await _teardownConnection();
  }

  /// Provider dispose 시 최종 정리 함수입니다.
  Future<void> dispose() async {
    _closed = true;
    await stop();
    await _signalController.close();
    await _statusController.close();
    _dio.close(force: true);
  }

  /// 실제 SSE 연결을 수행합니다.
  ///
  /// 흐름:
  /// 1) connecting 상태 전환
  /// 2) device secret 조회 및 헤더 주입
  /// 3) stream 연결
  /// 4) parser를 통해 signal 발행
  /// 5) 종료/오류 시 재연결 스케줄
  Future<void> _connect() async {
    if (!_running || _closed) {
      return;
    }

    _setStatus(GeofenceSseConnectionState.connecting);

    final secret = await _readDeviceSecret();
    if (secret == null || secret.isEmpty) {
      _scheduleReconnect('device secret missing');
      return;
    }

    try {
      final response = await _dio.get<ResponseBody>(
        ApiEndpoints.geofenceSlotsStream,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'X-Device-Secret': secret,
          },
        ),
      );

      final body = response.data;
      if (body == null) {
        _scheduleReconnect('empty stream response');
        return;
      }

      _retryAttempt = 0;
      _setStatus(GeofenceSseConnectionState.connected);
      _resetIdleTimer();

      // parser가 line 단위로 이벤트를 만들어주고,
      // 클라이언트는 이를 그대로 상위 스트림으로 전달합니다.
      _signalSubscription = _parser
          .parse(body.stream, onLineReceived: _resetIdleTimer)
          .listen(
            (signal) {
              _signalController.add(signal);
            },
            onDone: () {
              if (_running && !_closed) {
                _scheduleReconnect('stream closed');
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (_running && !_closed) {
                _logger.w('[SSE] stream error: $error');
                _scheduleReconnect('stream error');
              }
            },
            cancelOnError: true,
          );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      // 401/403은 재연결 반복해도 회복되지 않는 인증 오류로 간주합니다.
      // 상위 레이어가 재인증/재등록 흐름을 처리할 수 있도록 disconnected로 종료합니다.
      if (statusCode == 401 || statusCode == 403) {
        _running = false;
        _setStatus(
          GeofenceSseConnectionState.disconnected,
          reason: 'auth failed ($statusCode)',
        );
        return;
      }

      _scheduleReconnect('connect failed: ${e.message}');
    } catch (e) {
      _scheduleReconnect('connect failed: $e');
    }
  }

  /// 재연결을 예약합니다.
  ///
  /// 구현 의도:
  /// - 즉시 재접속 반복을 피하기 위해 백오프+지터 적용
  /// - 동시에 현재 연결 리소스를 먼저 정리
  void _scheduleReconnect(String reason) {
    if (!_running || _closed) {
      return;
    }

    unawaited(_teardownConnection());

    _retryAttempt += 1;
    final delay = _policy.computeReconnectDelay(_retryAttempt);

    _setStatus(
      GeofenceSseConnectionState.retrying,
      attempt: _retryAttempt,
      reason: reason,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  /// 유휴 타임아웃 타이머를 갱신합니다.
  ///
  /// 서버 heartbeat가 없더라도 "일정 시간 아무 줄도 수신되지 않으면"
  /// 연결 이상으로 판단해 재연결 루프로 복귀합니다.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(GeofenceSsePolicy.idleTimeout, () {
      if (_running && !_closed) {
        _scheduleReconnect('idle timeout');
      }
    });
  }

  /// 상태 변화를 외부에 발행합니다.
  void _setStatus(
    GeofenceSseConnectionState state, {
    int attempt = 0,
    String? reason,
  }) {
    _statusController.add(
      GeofenceSseStatus(state: state, attempt: attempt, reason: reason),
    );
  }

  /// 현재 연결과 관련된 리소스를 모두 정리합니다.
  Future<void> _teardownConnection() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _signalSubscription?.cancel();
    _signalSubscription = null;

    // ResponseBody.stream은 single-subscription 스트림입니다.
    // parser 구독(_signalSubscription)을 cancel하면 연결 정리가 끝나므로
    // 정리 단계에서 stream.listen(...)을 다시 호출하면 안 됩니다.
  }
}

final geofenceSseClientProvider = Provider<GeofenceSseClient>((ref) {
  final store = DeviceIdentityStore();

  final client = GeofenceSseClient(
    baseUrl: apiBaseUrl,
    readDeviceSecret: () => store.getDeviceSecret(),
  );

  ref.onDispose(() {
    unawaited(client.dispose());
  });

  return client;
});
