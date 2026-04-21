import 'package:permission_handler/permission_handler.dart';

//위치 권한 서비스 
// 권한 상태 조회, 권한 요청
class LocationPermissionService {
  //현재 앱의 위치 권한 상태 확인 
  //ios 기준 : denied/granted/permanentlyDenied 반환 
  Future<PermissionStatus> check() async {
    return Permission.locationWhenInUse.status;
  }

  Future<PermissionStatus> requestWhenInUse() async {
    return Permission.locationWhenInUse.request();
  }

  Future<PermissionStatus> requestAlways() async {
    return Permission.locationAlways.request();
  }

  Future<bool> isGranted() async {
    final status = await check();
    return status.isGranted;
  }
}
