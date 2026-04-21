import 'package:geolocator/geolocator.dart';

import '../network/api_exception.dart';
import 'location_permission_service.dart';

//실제 위치 조회를 담당하는 서비스
//권한 확인, 기기위치 서비스 ON/OFF 확인, 현재 위치 1회 조회
//현재 위치를 가져올 때 locationService.getCurrentPosition() 으로 호출해서 현재 위치 반환하면 됨 
class LocationService {
  final LocationPermissionService _permissionService;

  LocationService(this._permissionService);

  //현재 위치를 1회 조회해서 반환
  //실패 시 ApiException으로 통일해서 throw
  Future<Position> getCurrentPosition() async {
    // 1) 위치 권한 확인
    final granted = await _permissionService.isGranted();
    if (!granted) {
      throw const ApiException(
        code: 'LOCATION_PERMISSION_DENIED',
        message: '위치 권한이 필요합니다.',
      );
    }
    // 2) 기기 위치 서비스(위치 토글) ON/OFF 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const ApiException(
        code: 'LOCATION_SERVICE_DISABLED',
        message: '기기 위치 서비스가 꺼져 있습니다.',
      );
    }

    // 3) 현재 위치 1회 조회
    // high 정확도는 배터리 소모가 커질 수 있으니 추후 정책 조정 가능 
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }
}
