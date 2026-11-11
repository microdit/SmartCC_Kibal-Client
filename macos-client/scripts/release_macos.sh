#!/bin/bash
# Kibal macOS 버전 발행 — 버전 증가 → 검증 → Release 빌드 → DMG → 점검 → 체크섬 → (선택) 커밋·태그
#
# 사용:
#   ./scripts/release_macos.sh                  # patch 증가(0.0.16 → 0.0.17), 빌드번호 +1
#   ./scripts/release_macos.sh minor            # 0.0.16 → 0.1.0
#   ./scripts/release_macos.sh major            # 0.0.16 → 1.0.0
#   ./scripts/release_macos.sh 0.0.20           # 지정 버전
#   ./scripts/release_macos.sh --no-bump        # 현재 버전 그대로 재빌드(다른 Mac에서 빌드할 때)
# 옵션:
#   --skip-tests   flutter analyze/test 생략
#   --commit       pubspec 버전 변경 커밋 + 태그 macos-vX.Y.Z 생성(푸시는 git-sync.sh)
#   --install      빌드한 앱을 /Applications 에 설치(기존 앱 교체)
#
# 산출물: build/macos/Build/Products/Release/
#   macos_client_vX.Y.Z.dmg, macos_client_vX.Y.Z.dmg.sha256
set -euo pipefail

cd "$(dirname "$0")/.."
APP_DIR="$(pwd)"
OUT_DIR="build/macos/Build/Products/Release"

BUMP=patch
SKIP_TESTS=0
DO_COMMIT=0
DO_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    patch|minor|major) BUMP="$arg" ;;
    --no-bump) BUMP=none ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --commit) DO_COMMIT=1 ;;
    --install) DO_INSTALL=1 ;;
    [0-9]*.[0-9]*.[0-9]*) BUMP="$arg" ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $arg (--help 참고)" >&2; exit 2 ;;
  esac
done

step() { echo; echo "==== [$1] $2"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

# ── 1. 사전 점검 ──
step 1 "사전 점검"
command -v flutter >/dev/null || fail "flutter 없음 (PATH 확인)"
command -v xcodebuild >/dev/null || fail "Xcode 없음"
command -v pod >/dev/null || echo "WARN: CocoaPods(pod) 없음 — 플러그인 빌드 실패 가능"
echo "flutter: $(flutter --version 2>/dev/null | head -1)"
echo "host: $(scutil --get ComputerName 2>/dev/null || hostname) / $(uname -m)"

CUR=$(sed -E -n 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?$/\1/p' pubspec.yaml | head -1)
CUR_BUILD=$(sed -E -n 's/^version: [0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$/\1/p' pubspec.yaml | head -1)
CUR_BUILD=${CUR_BUILD:-0}
[ -n "$CUR" ] || fail "pubspec.yaml version 파싱 실패"

# ── 2. 버전 결정 ──
step 2 "버전 결정"
IFS=. read -r MA MI PA <<<"$CUR"
case "$BUMP" in
  none)  NEW="$CUR"; NEW_BUILD="$CUR_BUILD" ;;
  patch) NEW="$MA.$MI.$((PA + 1))"; NEW_BUILD=$((CUR_BUILD + 1)) ;;
  minor) NEW="$MA.$((MI + 1)).0"; NEW_BUILD=$((CUR_BUILD + 1)) ;;
  major) NEW="$((MA + 1)).0.0"; NEW_BUILD=$((CUR_BUILD + 1)) ;;
  *)     NEW="$BUMP"; NEW_BUILD=$((CUR_BUILD + 1)) ;;
esac
TAG="v$NEW"
echo "버전: $CUR+$CUR_BUILD → $NEW+$NEW_BUILD"
if [ "$BUMP" != "none" ]; then
  sed -i '' -E "s/^version: .*/version: $NEW+$NEW_BUILD/" pubspec.yaml
fi

# ── 3. 의존성 ──
step 3 "flutter pub get"
flutter pub get >/dev/null

# ── 4. 검증 ──
if [ "$SKIP_TESTS" = "0" ]; then
  step 4 "flutter analyze / test"
  flutter analyze || fail "analyze 실패"
  flutter test || fail "test 실패"
else
  step 4 "검증 생략(--skip-tests)"
fi

# ── 5. 빌드 + DMG ──
step 5 "Release 빌드 + DMG"
./scripts/build_macos.sh release

APP="$OUT_DIR/macos_client.app"
DMG="$OUT_DIR/macos_client_${TAG}.dmg"
[ -d "$APP" ] || fail "앱 없음: $APP"
[ -f "$DMG" ] || fail "DMG 없음: $DMG"

# ── 6. 산출물 점검 ──
step 6 "산출물 점검"
PLIST_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
[ "$PLIST_VER" = "$NEW" ] || fail "Info.plist 버전 불일치: $PLIST_VER != $NEW"
echo "Info.plist 버전: $PLIST_VER (build $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"))"
echo "아키텍처: $(lipo -archs "$APP/Contents/MacOS/macos_client")"
codesign --verify --deep --strict "$APP" || fail "codesign 검증 실패"
echo "서명: $(codesign -dv "$APP" 2>&1 | sed -n 's/^Signature=//p') (검증 OK)"

MNT=$(hdiutil attach -nobrowse -readonly "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF}')
trap '[ -n "${MNT:-}" ] && hdiutil detach -quiet "$MNT" 2>/dev/null || true' EXIT
[ -d "$MNT/macos_client.app" ] || fail "DMG에 앱 없음"
[ -L "$MNT/Applications" ] || fail "DMG의 Applications가 바로가기(링크)가 아님 — 끌어다 놓기 설치 불가"
DMG_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$MNT/macos_client.app/Contents/Info.plist")
[ "$DMG_VER" = "$NEW" ] || fail "DMG 내부 앱 버전 불일치: $DMG_VER"
hdiutil detach -quiet "$MNT"; MNT=""
echo "DMG 구성: macos_client.app + Applications 바로가기 (버전 $DMG_VER)"

# ── 7. 체크섬 ──
step 7 "체크섬"
SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo "$SHA  macos_client_${TAG}.dmg" >"$DMG.sha256"
SIZE=$(du -h "$DMG" | awk '{print $1}')
echo "sha256: $SHA ($SIZE)"

# ── 8. 설치(선택) ──
if [ "$DO_INSTALL" = "1" ]; then
  step 8 "/Applications 설치"
  pkill -x macos_client 2>/dev/null && sleep 1 || true
  rm -rf /Applications/macos_client.app
  cp -R "$APP" /Applications/
  xattr -dr com.apple.quarantine /Applications/macos_client.app 2>/dev/null || true
  echo "설치 완료: /Applications/macos_client.app"
fi

# ── 9. 커밋·태그(선택) ──
if [ "$DO_COMMIT" = "1" ] && [ "$BUMP" != "none" ]; then
  step 9 "커밋·태그"
  git add pubspec.yaml macos/Runner/Info.plist
  git commit -m "release(macos): $TAG+$NEW_BUILD" >/dev/null
  git tag -f "macos-$TAG"
  echo "커밋 $(git rev-parse --short HEAD), 태그 macos-$TAG (푸시: ../scripts/git-sync.sh --auto --no-deploy && git push origin macos-$TAG)"
fi

cat <<EOF

================================================
  발행 완료: $TAG (build $NEW_BUILD)
  DMG   : $APP_DIR/$DMG
  SHA256: $SHA
------------------------------------------------
  다른 Mac 설치:
    xattr -d com.apple.quarantine ~/Downloads/macos_client_${TAG}.dmg
    open ~/Downloads/macos_client_${TAG}.dmg   → 앱을 Applications로 끌어다 놓기
    xattr -dr com.apple.quarantine /Applications/macos_client.app
================================================
EOF
