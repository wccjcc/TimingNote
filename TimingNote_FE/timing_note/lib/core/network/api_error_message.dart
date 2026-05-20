import 'api_exception.dart';

/// BE `ApiResponseDto.error` → 사용자 친화 메시지로 변환.
///
/// 정책 (Hybrid):
/// 1. **알려진 도메인 코드**는 FE가 의도된 멘트로 매핑 — code별 부가 액션 연결을 위함
/// 2. **모르는 code**는 BE가 보낸 `error.message`를 그대로 노출 (대개 친절한 한국어)
/// 3. **둘 다 비어있으면** [action] 컨텍스트로 generic 폴백
///
/// BE 코드 형식은 `DOMAIN-STATUS-N` (예: `USER-409-1`).
/// 새 케이스 추가 시 [ErrorCode.java][ErrorCode]를 확인해 매칭하세요.
///
/// [ErrorCode]: TimingNote_BE/src/main/java/com/timingnote/api/common/exception/ErrorCode.java
String humanizeApiError(Object e, {required String action}) {
  if (e is! ApiException) {
    return '$action에 실패했어요. 잠시 후 다시 시도해 주세요';
  }

  // 1) 도메인 코드 매핑
  switch (e.code) {
    // USER 도메인
    case 'USER-409-1': // USER_PLACE_NAME_DUPLICATED
      return '이미 사용 중인 별칭이에요';
    case 'USER-409-2': // USER_PLACE_LIMIT_EXCEEDED
      // BE가 동적으로 한도를 메시지에 담아 보내므로 메시지 우선 (없으면 폴백)
      if (_hasUsableMessage(e)) return e.message;
      return '내 장소 등록 한도를 초과했어요';
    case 'USER-404-2': // USER_PLACE_NOT_FOUND
      return '해당 장소를 찾을 수 없어요';
    case 'USER-404-1': // USER_NOT_FOUND
      return '사용자 정보를 찾을 수 없어요';

    // COMMON 도메인
    case 'COMMON-401-1': // UNAUTHORIZED
      return '인증이 만료되었어요. 앱을 다시 실행해 주세요';
    case 'COMMON-403-1': // FORBIDDEN
      return '권한이 없어요';
    case 'COMMON-400-1': // VALIDATION_ERROR
      // 입력 검증은 BE가 구체적인 위반 사유를 message에 담는 경우가 많음 — 메시지 우선
      if (_hasUsableMessage(e)) return e.message;
      return '입력값을 다시 확인해 주세요';

    // FE 측 네트워크 폴백 (api_client._mapDioException)
    case 'NETWORK_ERROR':
      return '네트워크 연결을 확인해 주세요';
  }

  // 2) BE가 보낸 메시지가 쓸만하면 그대로
  if (_hasUsableMessage(e)) return e.message;

  // 3) Generic
  return '$action에 실패했어요. 잠시 후 다시 시도해 주세요';
}

bool _hasUsableMessage(ApiException e) {
  if (e.message.isEmpty) return false;
  // FE 내부 파싱/일반 에러 코드는 사용자에게 보여줄 메시지가 아님
  const internal = {'API_ERROR', 'PARSING_ERROR', 'INVALID_RESPONSE'};
  return !internal.contains(e.code);
}
