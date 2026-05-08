import 'dart:math';

/// Geofence SSE 재연결 정책을 한 곳에서 관리하기 위한 클래스입니다.

class GeofenceSsePolicy {
  GeofenceSsePolicy({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 서버 이벤트를 이 시간 동안 받지 못하면 연결이 멈춘 것으로 간주합니다.
  static const Duration idleTimeout = Duration(seconds: 60);

  /// 재시도 간격의 기준값(초)입니다.
  ///
  /// 시도 1회차: 1초
  /// 시도 2회차: 2초
  /// 시도 3회차: 4초
  /// 시도 4회차: 8초
  /// 시도 5회차 이상: 15초(상한)
  static const List<int> _baseSeconds = <int>[1, 2, 4, 8, 15];

  /// 지터 비율입니다. ±20% 범위에서 랜덤으로 흔들어 동시 재접속 폭주를 완화합니다.
  static const double _jitterRatio = 0.2;

  /// 재시도 횟수를 받아 실제 대기 시간을 계산합니다.
  Duration computeReconnectDelay(int attempt) {
    final index = (attempt - 1).clamp(0, _baseSeconds.length - 1);
    final base = _baseSeconds[index];

    final minRatio = 1.0 - _jitterRatio;
    final maxRatio = 1.0 + _jitterRatio;
    final ratio = minRatio + (_random.nextDouble() * (maxRatio - minRatio));

    final seconds = (base * ratio).clamp(0.2, 15.0);
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
