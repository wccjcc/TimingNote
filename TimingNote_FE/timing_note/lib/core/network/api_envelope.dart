// 서버 에러 블록 모델
class ApiError {
  final String code;
  final String message;

  const ApiError({
    required this.code,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code']?.toString() ?? 'UNKNOWN_ERROR',
      message: json['message']?.toString() ?? '알 수 없는 오류',
    );
  }
}

// 서버 공통 응답 포맷 모델
// {
//   "success": true/false,
//   "data": ...,
//   "msg": "...",
//   "error": { "code": "...", "message": "..." }
// }
class ApiEnvelope<T> {
  final bool success;
  final T? data;
  final String? msg;
  final ApiError? error;

  const ApiEnvelope({
    required this.success,
    this.data,
    this.msg,
    this.error,
  });

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic json)? dataParser,
  }) {
    final dynamic rawData = json['data'];

    return ApiEnvelope<T>(
      success: json['success'] == true,
      data: rawData == null
          ? null
          : (dataParser != null ? dataParser(rawData) : rawData as T),
      msg: json['msg']?.toString(),
      error: json['error'] == null
          ? null
          : ApiError.fromJson(json['error'] as Map<String, dynamic>),
    );
  }
}
