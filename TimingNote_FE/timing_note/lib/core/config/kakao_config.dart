// .env의 KAKAO_NATIVE_APP_KEY를 --dart-define-from-file=.env 플래그로 주입받는다.
//
// REST API key는 더 이상 FE에 두지 않는다.
// 검색/역지오코딩은 BE 프록시(/api/v1/places/*)를 거치고, 키는 BE 환경변수로 격리.
// Native SDK 키는 KakaoMapsSDK가 자체적으로 앱 번들 ID로 검증하므로 노출되어도 안전.
class KakaoConfig {
  static const String nativeAppKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
}
