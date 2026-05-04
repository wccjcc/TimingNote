#!/bin/bash
ENV_FILE="../../.env"

case "$1" in
  web)
    flutter run -d chrome --dart-define-from-file=$ENV_FILE
    ;;
  release)
    flutter run --release --dart-define-from-file=$ENV_FILE
    ;;
  build-apk)
    flutter build apk --dart-define-from-file=$ENV_FILE
    ;;
  build-ios)
    flutter build ios --dart-define-from-file=$ENV_FILE
    ;;
  clean)
    flutter clean
    ;;
  pub)
    flutter pub get
    ;;
  *)
    flutter run --dart-define-from-file=$ENV_FILE
    ;;
esac
