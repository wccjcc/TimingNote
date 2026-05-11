import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱에서 공통으로 쓰는 위경도 값 객체입니다.
///
/// 기존 지도 플러그인의 LatLng 타입에 화면 코드가 강하게 묶이지 않도록,
/// 네이티브 지도 브릿지에서 필요한 최소 정보만 담습니다.
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// 디버깅용 후보 장소 마커 데이터.
///
/// 활성 슬롯(`active: true`)은 강조 색으로, 비활성은 디머된 색으로 표시된다.
class CandidateMarker {
  const CandidateMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.active,
  });

  final String id;
  final double latitude;
  final double longitude;
  final bool active;

  Map<String, Object> toMap() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'active': active,
      };
}

/// iOS 네이티브 KakaoMapsSDK 지도 컨트롤러입니다.
///
/// Flutter는 네이티브 UIView를 직접 조작할 수 없기 때문에 MethodChannel로
/// "지도를 특정 좌표로 이동" 같은 명령만 전달합니다.
class NativeKakaoMapController {
  NativeKakaoMapController._(int viewId)
    : _channel = MethodChannel('timing_note/native_kakao_map_$viewId');

  final MethodChannel _channel;

  Future<void> panTo(LatLng target) {
    return _channel.invokeMethod<void>('panTo', {
      'latitude': target.latitude,
      'longitude': target.longitude,
    });
  }

  /// 후보 장소 마커들을 지도에 표시합니다.
  /// 동일 메서드를 다시 호출하면 기존 마커는 제거되고 새 목록으로 교체됩니다.
  Future<void> setMarkers(List<CandidateMarker> markers) {
    return _channel.invokeMethod<void>('setMarkers', {
      'markers': markers.map((m) => m.toMap()).toList(),
    });
  }
}

class NativeKakaoMap extends StatefulWidget {
  const NativeKakaoMap({
    super.key,
    required this.center,
    required this.onMapCreated,
    required this.onCameraIdle,
    required this.onCameraMoveStarted,
    this.initialLevel = 15,
  });

  final LatLng center;
  final int initialLevel;
  final ValueChanged<NativeKakaoMapController> onMapCreated;
  final void Function(LatLng center, int zoomLevel) onCameraIdle;
  final VoidCallback onCameraMoveStarted;

  @override
  State<NativeKakaoMap> createState() => _NativeKakaoMapState();
}

class _NativeKakaoMapState extends State<NativeKakaoMap> {
  static const String _viewType = 'timing_note/native_kakao_map';
  MethodChannel? _eventChannel;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const ColoredBox(
        color: Color(0xFF1A1A2E),
        child: Center(
          child: Icon(Icons.map_outlined, color: Colors.white24, size: 56),
        ),
      );
    }

    return UiKitView(
      viewType: _viewType,
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: {
        'latitude': widget.center.latitude,
        'longitude': widget.center.longitude,
        'level': widget.initialLevel,
      },
      // 지도는 드래그/핀치 제스처를 네이티브 뷰가 바로 받아야 자연스럽습니다.
      // EagerGestureRecognizer를 쓰면 Flutter 스크롤 제스처와 경쟁하지 않고
      // iOS 지도 SDK가 터치를 즉시 처리할 수 있습니다.
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onPlatformViewCreated: (viewId) {
        final controller = NativeKakaoMapController._(viewId);
        _eventChannel = MethodChannel('timing_note/native_kakao_map_$viewId')
          ..setMethodCallHandler(_handleNativeEvent);
        widget.onMapCreated(controller);
      },
    );
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onCameraMoveStarted':
        widget.onCameraMoveStarted();
        return;
      case 'onCameraIdle':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        final latitude = (args['latitude'] as num).toDouble();
        final longitude = (args['longitude'] as num).toDouble();
        final level = (args['level'] as num?)?.toInt() ?? widget.initialLevel;
        widget.onCameraIdle(LatLng(latitude, longitude), level);
        return;
    }
  }

  @override
  void dispose() {
    _eventChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}
