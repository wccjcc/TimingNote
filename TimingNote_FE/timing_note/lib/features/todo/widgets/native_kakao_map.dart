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

/// 후보 장소/지도 탭 화면의 todo 마커 데이터.
///
/// 활성(`active: true`)은 강조 색으로, 비활성은 디머된 색으로 표시된다.
/// `placeType`을 지정하면 Swift 측이 타입별 색(SPECIFIC 보라/ALIAS 노랑/GENERIC cyan)으로
/// 핀을 그린다. null이면 기존 default 색(초록/회색) 그대로.
/// `badgeText`를 지정하면 핀 위에 항상 보이는 작은 숫자/텍스트 배지를 그린다.
/// `compact`는 상세 화면 미니 지도처럼 좁은 영역에서 쓰는 작은 핀이다.
class CandidateMarker {
  const CandidateMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.active,
    this.name,
    this.placeType,
    this.badgeText,
    this.compact = false,
  });

  final String id;
  final double latitude;
  final double longitude;
  final bool active;

  /// 마커 클릭 시 마커 위에 띄울 장소명. null이면 라벨 미표시.
  final String? name;

  /// 'SPECIFIC' | 'ALIAS' | 'GENERIC' (TodoType 상수와 동일).
  /// null이면 Swift 측 default 색 적용 (상세 페이지 후보 마커 등 호환).
  final String? placeType;

  /// 지도 탭처럼 마커 위에 항상 보여야 하는 짧은 배지 텍스트.
  /// 예: 같은 장소에 등록된 할 일 개수 "3".
  final String? badgeText;

  final bool compact;

  Map<String, Object> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'active': active,
    if (name != null) 'name': name!,
    if (placeType != null) 'placeType': placeType!,
    if (badgeText != null) 'badgeText': badgeText!,
    if (compact) 'compact': compact,
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

  /// 사용자 GPS 위치 마커(흰 코어 + 보라 ring)를 표시. 좌표 변경 시 같은 PoiID로 갱신됨.
  /// todo 마커와 형태(원 vs 핀) + 색 구분으로 시각적으로 즉시 분리됨.
  Future<void> setUserLocation(LatLng position) {
    return _channel.invokeMethod<void>('setUserLocation', {
      'latitude': position.latitude,
      'longitude': position.longitude,
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
    this.onTap,
    this.onMarkerTap,
    this.initialLevel = 15,
  });

  final LatLng center;
  final int initialLevel;
  final ValueChanged<NativeKakaoMapController> onMapCreated;
  final void Function(LatLng center, int zoomLevel) onCameraIdle;
  final VoidCallback onCameraMoveStarted;

  /// 지도 빈 공간 탭 시 호출. (키보드 닫기 등 용도)
  final VoidCallback? onTap;

  /// 마커(Poi) 탭 시 setMarkers에서 전달한 marker.id를 콜백으로 전달.
  /// null이면 탭 이벤트 무시.
  final ValueChanged<String>? onMarkerTap;

  @override
  State<NativeKakaoMap> createState() => _NativeKakaoMapState();
}

class _NativeKakaoMapState extends State<NativeKakaoMap> {
  static const String _viewType = 'timing_note/native_kakao_map';
  MethodChannel? _eventChannel;
  // KakaoMap 엔진 준비 신호 — 첫 onCameraIdle 이벤트(=addViewSucceeded 후) 시점에 true.
  // 그 전엔 placeholder + CircularProgressIndicator 위에 덮어서 빈 화면 인상 제거.
  bool _isMapReady = false;

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

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          child: UiKitView(
            viewType: _viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: {
              'latitude': widget.center.latitude,
              'longitude': widget.center.longitude,
              'level': widget.initialLevel,
            },
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            },
            onPlatformViewCreated: (viewId) {
              final controller = NativeKakaoMapController._(viewId);
              _eventChannel = MethodChannel(
                'timing_note/native_kakao_map_$viewId',
              )..setMethodCallHandler(_handleNativeEvent);
              widget.onMapCreated(controller);
            },
          ),
        ),
        // 엔진 준비 전 placeholder — IgnorePointer로 지도 제스처 영향 X.
        // ready 후엔 안 그려지므로 추가 비용 없음.
        if (!_isMapReady)
          const IgnorePointer(
            child: ColoredBox(
              color: Color(0xFF1A1A2E),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFA78BFA),
                  ),
                ),
              ),
            ),
          ),
      ],
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
        // 첫 idle = 엔진 준비 완료 신호. placeholder 제거.
        if (!_isMapReady && mounted) {
          setState(() => _isMapReady = true);
        }
        return;
      case 'onPoiTapped':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        final id = args['id'] as String?;
        if (id != null) widget.onMarkerTap?.call(id);
        return;
    }
  }

  @override
  void dispose() {
    _eventChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}
