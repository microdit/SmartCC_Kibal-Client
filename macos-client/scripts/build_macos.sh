#!/bin/bash
# Kibal macOS 빌드 — 버전 표기 통일
#   - pubspec.yaml의 version을 단일 소스로 사용
#   - DMG 파일명: macos_client_vX.Y.Z.dmg
#   - 앱 타이틀바: dart-define APP_VERSION 전달 (KibalApp이 표시)
#   - Info.plist CFBundleShortVersionString 동기화
# 사용: ./scripts/build_macos.sh [debug|release] [--no-dmg]
# 버전 발행(버전 증가·검증·DMG·체크섬·커밋)은 ./scripts/release_macos.sh 사용
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=release
MAKE_DMG=1
for arg in "$@"; do
  case "$arg" in
    debug|release) CONFIG="$arg" ;;
    --no-dmg) MAKE_DMG=0 ;;
    *) echo "알 수 없는 인자: $arg (사용: [debug|release] [--no-dmg])" >&2; exit 2 ;;
  esac
done

VERSION=$(sed -E -n 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+.*)?$/\1/p' pubspec.yaml | head -1)
BUILD=$(sed -E -n 's/^version: [0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$/\1/p' pubspec.yaml | head -1)
TAG="v${VERSION}"
# 실제 빌드 산출 폴더명(Release/Debug) — 대소문자 구분 파일시스템 대비
CONFIG_DIR="$(echo "${CONFIG:0:1}" | tr '[:lower:]' '[:upper:]')${CONFIG:1}"
OUT_DIR="build/macos/Build/Products/${CONFIG_DIR}"
echo ">>> build config=$CONFIG version=$TAG build=${BUILD:-1}"

# pubspec version을 Info.plist에도 반영 (CFBundleShortVersionString/BundleVersion)
PLIST=macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$PLIST"
if [ -n "$BUILD" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD}" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD}" "$PLIST"
fi

# Flutter 빌드 (dart-define으로 버전 전달 → 타이틀바 표시)
flutter build macos --"$CONFIG" --dart-define=APP_VERSION="$TAG"

if [ "$MAKE_DMG" = "1" ]; then
  DMG_NAME="macos_client_${TAG}.dmg"
  ROOT=$(mktemp -d /tmp/kibal-dmg-root.XXXXXX)
  cp -R "${OUT_DIR}/macos_client.app" "$ROOT/"
  # /Applications 바로가기(심볼릭 링크) — 폴더를 만들면 안 됨(끌어다 놓기 설치 불가)
  ln -s /Applications "$ROOT/Applications"
  hdiutil create -volname "SmartCC Kibal macOS Client $TAG" \
    -srcfolder "$ROOT" -ov -format UDZO "${OUT_DIR}/${DMG_NAME}" >/dev/null
  rm -rf "$ROOT"
  echo ">>> dmg: ${OUT_DIR}/${DMG_NAME}"
fi
