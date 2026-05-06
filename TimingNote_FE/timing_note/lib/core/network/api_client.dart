import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'api_envelope.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required Future<String?> Function() readDeviceSecret,
  })  : _readDeviceSecret = readDeviceSecret,
        // 앱 전체 공통 Dio 설정
        // - baseUrl: 모든 API 요청 prefix
        // - timeout: 무한 대기 방지
        // - headers: 기본 JSON 요청 포맷
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: const {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // SYS-01처럼 헤더 제외가 필요한 경우만 skipDeviceSecret=true 전달
          final bool skip = options.extra['skipDeviceSecret'] == true;

          // 기본 정책: 모든 요청에 X-Device-Secret 자동 주입
          if (!skip) {
            final deviceSecret = await _readDeviceSecret();
            if (deviceSecret != null && deviceSecret.isNotEmpty) {
              options.headers['X-Device-Secret'] = deviceSecret;
            }
          }

          // 전역 로깅 규칙: 네트워크 로그는 interceptor에서만 출력
          _logger.i('[REQ] ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.i(
            '[RES] ${response.statusCode} '
            '${response.requestOptions.method} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            '[ERR] ${error.response?.statusCode ?? '-'} '
            '${error.requestOptions.method} ${error.requestOptions.uri} '
            '${error.message}',
          );
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final Future<String?> Function() _readDeviceSecret;
  final Logger _logger = Logger();

  // 이제 모든 메서드는 data만이 아니라 msg까지 살리기 위해
  // ApiEnvelope<T> 자체를 반환한다.
  Future<ApiEnvelope<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {'skipDeviceSecret': skipDeviceSecret}),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<ApiEnvelope<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: {'skipDeviceSecret': skipDeviceSecret}),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<ApiEnvelope<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: {'skipDeviceSecret': skipDeviceSecret}),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<ApiEnvelope<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: {'skipDeviceSecret': skipDeviceSecret}),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<ApiEnvelope<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: {'skipDeviceSecret': skipDeviceSecret}),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // 파일 업로드 전용 메서드
  // - 요청 Content-Type만 multipart/form-data로 전환
  // - 응답은 동일하게 ApiEnvelope<T>로 파싱
  Future<ApiEnvelope<T>> upload<T>(
    String path, {
    required String fileField,
    required File file,
    Map<String, dynamic>? fields,
    T Function(dynamic json)? dataParser,
    bool skipDeviceSecret = false,
  }) async {
    try {
      final formMap = <String, dynamic>{
        ...?fields,
        fileField: await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      };

      final response = await _dio.post(
        path,
        data: FormData.fromMap(formMap),
        options: Options(
          extra: {'skipDeviceSecret': skipDeviceSecret},
          contentType: 'multipart/form-data',
        ),
      );

      return _unwrapResponse<T>(response, dataParser: dataParser);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // 서버 공통 응답 포맷 해석
  // 기대 형태: { success, data, msg, error }
  // success=false일 때는 ApiException으로 변환해 throw한다.
  ApiEnvelope<T> _unwrapResponse<T>(
    Response response, {
    T Function(dynamic json)? dataParser,
  }) {
    try {
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const ApiException(
          code: 'INVALID_RESPONSE',
          message: 'Response format is invalid.',
        );
      }

      final envelope = ApiEnvelope<T>.fromJson(raw, dataParser: dataParser);

      if (!envelope.success) {
        throw ApiException(
          code: envelope.error?.code ?? 'API_ERROR',
          message: envelope.error?.message ?? 'Request failed.',
          statusCode: response.statusCode,
          // 백엔드가 error 응답에 담아주는 data를 보존
          data: envelope.data,
        );
      }

      return envelope;
    } on ApiException {
      rethrow;
    } catch (e) {
      // 파싱/캐스팅 오류도 ApiException으로 통일해 상위 레이어 처리 단순화
      throw ApiException(
        code: 'PARSING_ERROR',
        message: '응답 파싱 중 오류가 발생했습니다: $e',
        statusCode: response.statusCode,
      );
    }
  }

  // DioException -> ApiException 변환
  // 서버가 표준 에러 포맷을 준 경우 code/message/data를 최대한 보존한다.
  ApiException _mapDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    if (responseData is Map<String, dynamic>) {
      try {
        final envelope = ApiEnvelope<dynamic>.fromJson(responseData);
        if (envelope.error != null) {
          return ApiException(
            code: envelope.error!.code,
            message: envelope.error!.message,
            statusCode: statusCode,
            data: envelope.data,
          );
        }
      } catch (_) {
        // 파싱 실패 시 아래 기본 네트워크 에러로 폴백
      }
    }

    return ApiException(
      code: 'NETWORK_ERROR',
      message: e.message ?? 'Network error occurred.',
      statusCode: statusCode,
    );
  }
}
