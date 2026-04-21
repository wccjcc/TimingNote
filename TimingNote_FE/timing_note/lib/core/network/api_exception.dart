// 네트워크/서버 예외를 앱에서 공통으로 다루기 위한 모델
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  // 백엔드가 error 응답에서 data를 내려주는 케이스(BusinessException) 보존용
  final dynamic data;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() {
    return 'ApiException(code: $code, message: $message, statusCode: $statusCode, data: $data)';
  }
}