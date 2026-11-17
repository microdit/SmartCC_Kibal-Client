#!/bin/bash
# Kibal macOS DMG 빌더 — 산출물을 프로젝트 루트에 생성
# @>-- 2026-11-17 microdit: --auto / --interactive, debug/release 별 산출물
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CLIENT_DIR="$ROOT_DIR/macos-client"
INTERACTIVE=true
AUTO_MODE=false
INTERACTIVE_EXPLICIT=false
CONFIG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO_MODE=true; INTERACTIVE=false; INTERACTIVE_EXPLICIT=false; shift ;;
        --interactive) INTERACTIVE=true; AUTO_MODE=false; INTERACTIVE_EXPLICIT=true; shift ;;
        --debug) CONFIG=debug; shift ;;
        --release) CONFIG=release; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --interactive   대화형 모드 (빌드 모드 선택), 기본값"
            echo "  --auto          자동 모드 (프롬프트 없음, 기본 release)"
            echo "  --debug         debug 빌드 지정"
            echo "  --release       release 빌드 지정"
            echo "  -h, --help      도움말 표시"
            echo ""
            echo "산출물 (프로젝트 루트):"
            echo "  release: macos_client_vX.Y.Z.dmg  (+ .sha256)"
            echo "  debug:   macos_client_vX.Y.Z_debug.dmg  (+ .sha256, .app 복사)"
            echo ""
            echo "참고: --auto 와 --interactive 를 함께 쓰면 마지막 옵션이 적용됩니다."
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1 ;;
    esac
done

# ── 빌드 모드 결정 ──
if [ -n "$CONFIG" ]; then
    echo "모드: $CONFIG (옵션 지정)"
elif [ "$AUTO_MODE" = true ]; then
    CONFIG=release
    echo "모드: release (자동 기본값)"
elif [ "$INTERACTIVE_EXPLICIT" = false ] && [ ! -t 0 ]; then
    echo "(비대화형 환경 — 자동 모드로 전환)"
    AUTO_MODE=true
    INTERACTIVE=false
    CONFIG=release
else
    echo "================================================"
    echo "  macOS DMG 빌더"
    echo "================================================"
    echo "  빌드 모드 선택"
    echo "    1) release  — 배포용 DMG"
    echo "    2) debug    — 테스트용 DMG + .app 복사"
    echo
    echo -n "  선택 [1/2] (Enter=release): "
    read -r sel
    case "$sel" in
        2|2\)) CONFIG=debug ;;
        *) CONFIG=release ;;
    esac
fi

if [ "$CONFIG" != debug ] && [ "$CONFIG" != release ]; then
    echo "ERROR: 지원하지 않는 모드 ($CONFIG). debug 또는 release만 가능합니다."
    exit 1
fi

echo
echo ">>> 빌드 모드: $CONFIG"

# ── 사전 점검 ──
if ! command -v flutter >/dev/null 2>&1; then
    echo "ERROR: flutter가 PATH에 없습니다."
    exit 1
fi
if ! command -v hdiutil >/dev/null 2>&1; then
    echo "ERROR: hdiutil 미지원 — macOS에서만 실행할 수 있습니다."
    exit 1
fi
if [ ! -f "$CLIENT_DIR/pubspec.yaml" ]; then
    echo "ERROR: pubspec.yaml 없음: $CLIENT_DIR/pubspec.yaml"
    exit 1
fi

VERSION=$(sed -E -n 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+.*)?$/\1/p' "$CLIENT_DIR/pubspec.yaml" | head -1)
BUILD=$(sed -E -n 's/^version: [0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$/\1/p' "$CLIENT_DIR/pubspec.yaml" | head -1)
if [ -z "$VERSION" ]; then
    echo "ERROR: pubspec.yaml에서 version을 찾을 수 없습니다."
    exit 1
fi
TAG="v${VERSION}"
CONFIG_DIR="$(echo "${CONFIG:0:1}" | tr '[:lower:]' '[:upper:]')${CONFIG:1}"
APP_PATH="$CLIENT_DIR/build/macos/Build/Products/${CONFIG_DIR}/macos_client.app"

echo ">>> 버전: $TAG (build ${BUILD:-1})"
echo ">>> 앱 산출 경로: $APP_PATH"
echo

# ── Flutter 빌드 (기존 build_macos.sh 재사용, DMG는 루트에서 직접 생성) ──
echo "[1/3] flutter build macos --$CONFIG ..."
if ! (cd "$CLIENT_DIR" && ./scripts/build_macos.sh "$CONFIG" --no-dmg); then
    echo "ERROR: Flutter 빌드 실패"
    exit 1
fi
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: 앱 산출물이 없습니다: $APP_PATH"
    exit 1
fi

# ── DMG 생성 (프로젝트 루트) ──
if [ "$CONFIG" = debug ]; then
    DMG_NAME="macos_client_${TAG}_debug.dmg"
    VOL_NAME="SmartCC Kibal macOS Client ${TAG} Debug"
else
    DMG_NAME="macos_client_${TAG}.dmg"
    VOL_NAME="SmartCC Kibal macOS Client ${TAG}"
fi
DMG_PATH="$ROOT_DIR/$DMG_NAME"

echo "[2/3] DMG 생성: $DMG_PATH"
STAGE=$(mktemp -d /tmp/kibal-dmg-root.XXXXXX)
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
if ! hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null; then
    rm -rf "$STAGE"
    echo "ERROR: DMG 생성 실패"
    exit 1
fi
rm -rf "$STAGE"

if ! shasum -a 256 "$DMG_PATH" | awk '{print $1}' > "${DMG_PATH}.sha256"; then
    echo "WARN: 체크섬 생성 실패"
fi

# debug 모드 전용 산출물: 루트에 .app 복사 (빠른 실행/테스트용)
if [ "$CONFIG" = debug ]; then
    APP_OUT="$ROOT_DIR/macos_client_${TAG}_debug.app"
    echo "  debug 전용 앱 복사: $APP_OUT"
    rm -rf "$APP_OUT"
    cp -R "$APP_PATH" "$APP_OUT"
fi

# ── 결과 보고 ──
echo "[3/3] 완료"
echo "-----------------------------------------------"
echo "  모드: $CONFIG"
echo "  버전: $TAG (build ${BUILD:-1})"
echo "  DMG:  $DMG_PATH"
echo "  크기: $(du -h "$DMG_PATH" | awk '{print $1}')"
if [ -f "${DMG_PATH}.sha256" ]; then
    echo "  sha256: $(cat "${DMG_PATH}.sha256")"
fi
if [ "$CONFIG" = debug ]; then
    echo "  앱:   $ROOT_DIR/macos_client_${TAG}_debug.app"
fi
echo "-----------------------------------------------"
