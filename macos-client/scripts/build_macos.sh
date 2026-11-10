#!/bin/bash
# Kibal macOS 빌드 — 버전 표기 통일
#   - pubspec.yaml의 version을 단일 소스로 사용
#   - DMG 파일명: macos_client_vX.Y.Z.dmg
#   - 앱 타이틀바: dart-define APP_VERSION 전달 (KibalApp이 표시)
#   - Info.plist CFBundleShortVersionString 동기화
# 사용: ./scripts/build_macos.sh [debug|release] [--no-dmg]
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
DMG="${2:-dmg}"
[[ "$1" == "--no-dfg" ]] && CONFIG=release && DMG=api
# 인자 정규화
case "${1:-release}" in
  debug|release) CONFIG="$1" ;;
  *) CONFIG=release ;;
esac

VERSION=$(sed -E -n 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+.*)?$/\1/p' pubspec.yaml | head -1)
TAG="v${VERSION}"
CONFIG_DIR="$(echo "$CONFIG" | tr '[:lower:]' '[:upper:]')"
echo ">>> build config=$CONFIG version=$TAG"

# pubspec version을 Info.plist에도 반영 (CFBundleShortVersionString)
PLIST=macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$PLIST"

# Flutter 빌드 (dart-define으로 버전 전달 → 타이틀바 표시)
flutter build macos --"$CONFIG" --dart-define=APP_VERSION="$TAG"

if [ "$DMG" != "--no-dmg" ]; then
  DMG_NAME="macos_client_${TAG}.dmg"
  rm -rf /tmp/kibal-dmg-root
  mkdir -p /tmp/kibal-dmg-root/Applications
  cp -R "build/macos/Build/Products/${CONFIG_DIR}/macos_client.app" /tmp/kibal-dmg-root/
  ln -sf /Applications /tmp/kibal-dmg-root/Applications
  hdiutil create -volname "SmartCC Kibal macOS Client $TAG" \
    -srcfolder /tmp/kibal-dmg-root -ov -format UDZO \
    "build/macos/Build/Products/${CONFIG_DIR}/${DMG_NAME}" >/dev/null 2>&1
  echo ">>> dmg 항: build/macos/Build/Products/${CONFIG_DIR}/${DMG_NAME}"
fi
