import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'geofence_sse_models.dart';

/// SSE 원시 바이트 스트림을 GeofenceSseSignal 스트림으로 변환하는 전용 파서입니다.
///

class GeofenceSseParser {
  /// [byteStream]은 Dio ResponseBody.stream입니다.
  /// [onLineReceived]는 줄 단위 데이터 수신 시 호출되며, 유휴 타임아웃 리셋에 사용됩니다.
  Stream<GeofenceSseSignal> parse(
    Stream<Uint8List> byteStream, {
    void Function()? onLineReceived,
  }) async* {
    String? currentEvent;
    String? currentId;
    final dataBuffer = StringBuffer();

    // 1) byte -> utf8 string
    // 2) string -> line 단위 분해
    final lineStream = byteStream
        .map((chunk) => utf8.decode(chunk, allowMalformed: true))
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      onLineReceived?.call();

      // 빈 줄은 "한 이벤트 블록 끝"을 의미합니다.
      if (line.isEmpty) {
        if (currentEvent != null || currentId != null || dataBuffer.isNotEmpty) {
          yield GeofenceSseSignal(
            event: currentEvent ?? 'message',
            id: currentId,
            data: dataBuffer.isEmpty ? null : dataBuffer.toString(),
          );
        }

        currentEvent = null;
        currentId = null;
        dataBuffer.clear();
        continue;
      }

      // ':' 라인은 서버 주석/heartbeat 성격이므로 payload로 쓰지 않습니다.
      if (line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('id:')) {
        currentId = line.substring(3).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        if (dataBuffer.isNotEmpty) {
          dataBuffer.write('\n');
        }
        dataBuffer.write(line.substring(5).trim());
      }
    }
  }
}
