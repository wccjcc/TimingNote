import 'package:permission_handler/permission_handler.dart';

//위치 권한 서비스 
// 권한 상태 조회, 권한 요청
class LocationPermissionService {
  //현재 앱의 위치 권한 상태 확인 
  //ios 기준 : denied/granted/permanentlyDenied 반환 
  Future<PermissionStatus> check() async {
    return Permission.locationWhenInUse.status;
  }

  //앱 사용 중 위치 권한(When In Use) 요청
  Future<PermissionStatus> requestWhenInUse() async {
    return Permission.locationWhenInUse.request();
  }

  //항상 허용(Always) 권한 요청
  //주의 : ios는 먼저 when in use 허용 후 Always 요청이 자연스러움 
  Future<PermissionStatus> requestAlways() async {
    return Permission.locationAlways.request();
  }

  //현재 권한이 허용 상태인지 bool로 빠르게 확인
  Future<bool> isGranted() async {
    final status = await check();
    return status.isGranted;
  }
}
