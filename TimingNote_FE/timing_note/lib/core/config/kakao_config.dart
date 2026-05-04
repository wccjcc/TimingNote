// .env 파일의 KAKAO_API_KEY, KAKAO_NATIVE_APP_KEY를
// --dart-define-from-file=.env 플래그로 주입받는다.
class KakaoConfig {
  static const String restApiKey =
      String.fromEnvironment('KAKAO_API_KEY');
  static const String nativeAppKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
}
