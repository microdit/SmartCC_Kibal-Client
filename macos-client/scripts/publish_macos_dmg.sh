#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_DMG="$APP_DIR/build/macos/Build/Products/Release"
SHARE_DIR="${KIBAL_DMG_SHARE_DIR:-/Volumes/NetBackup/보관함/개발/Live_Log}"
DRY_RUN=0
DMG=""

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --share-dir)
      [ $# -ge 2 ] || fail "--share-dir 경로 필요"
      SHARE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [DMG_PATH] [--share-dir DIR] [--dry-run]"
      echo "Default share: /Volumes/NetBackup/보관함/개발/Live_Log"
      exit 0
      ;;
    *)
      [ -z "$DMG" ] || fail "DMG_PATH는 하나만 지정할 수 있습니다"
      DMG="$1"
      shift
      ;;
  esac
done

if [ -z "$DMG" ]; then
  VERSION=$(sed -n 's/^version: //p' "$APP_DIR/pubspec.yaml" | head -1)
  VERSION_NO_BUILD="${VERSION%%+*}"
  DMG="$DEFAULT_DMG/macos_client_v${VERSION_NO_BUILD}.dmg"
fi

[ -f "$DMG" ] || fail "DMG 없음: $DMG"
VERSION=$(basename "$DMG" | sed -E -n 's/^macos_client_v([0-9]+\.[0-9]+\.[0-9]+)\.dmg$/\1/p')
[ -n "$VERSION" ] || fail "DMG 파일명에서 버전을 확인할 수 없습니다: $DMG"

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
DEST_NAME="macOS_Client_v${VERSION}.dmg"
DEST="$SHARE_DIR/$DEST_NAME"
SHA_FILE="$DEST.sha256"
LATEST="$SHARE_DIR/macOS_Client_LATEST.txt"
HOST=$(scutil --get ComputerName 2>/dev/null || hostname)
PUBLISHED_AT=$(date '+%Y-%m-%d %H:%M:%S %Z')

if [ "$DRY_RUN" = 1 ]; then
  echo "SOURCE=$DMG"
  echo "DEST=$DEST"
  echo "SHA256=$SHA"
  echo "LATEST=$LATEST"
  exit 0
fi

if [ ! -d "$SHARE_DIR" ]; then
  echo "SKIP: NAS 공유폴더 미마운트/없음: $SHARE_DIR" >&2
  echo "LOCAL_ONLY: $DMG" >&2
  exit 3
fi
if [ ! -w "$SHARE_DIR" ]; then
  echo "SKIP: NAS 공유폴더 쓰기 불가: $SHARE_DIR" >&2
  echo "LOCAL_ONLY: $DMG" >&2
  exit 4
fi

TMP_DMG="$DEST.tmp.$$"
TMP_SHA="$SHA_FILE.tmp.$$"
TMP_LATEST="$LATEST.tmp.$$"
trap 'rm -f "$TMP_DMG" "$TMP_SHA" "$TMP_LATEST"' EXIT

cp "$DMG" "$TMP_DMG"
printf '%s  %s\n' "$SHA" "$DEST_NAME" >"$TMP_SHA"
printf 'version=%s\nfile=%s\nsha256=%s\nsource_host=%s\npublished_at=%s\n' \
  "$VERSION" "$DEST_NAME" "$SHA" "$HOST" "$PUBLISHED_AT" >"$TMP_LATEST"

mv "$TMP_DMG" "$DEST"
mv "$TMP_SHA" "$SHA_FILE"
mv "$TMP_LATEST" "$LATEST"

PUBLISHED_SHA=$(shasum -a 256 "$DEST" | awk '{print $1}')
[ "$PUBLISHED_SHA" = "$SHA" ] || fail "공유폴더 체크섬 불일치: $DEST"

echo "PUBLISH_OK=1"
echo "SOURCE=$DMG"
echo "SHARED_DMG=$DEST"
echo "SHA256=$SHA"
echo "LATEST=$LATEST"
