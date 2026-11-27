#!/bin/bash
# Kibal (SmartCC IP-PBX) Git Pull
# Fetch + Pull + Branch Selector (macOS/Linux)
# @>-- 2026-10-29 microdit: SmartCC_Kibal 프로젝트 맞춤
# @>-- 2026-10-29 옵션 처리 추가: --auto (자동), --interactive (대화식)
set -uo pipefail

# 옵션 파싱
INTERACTIVE=true
AUTO_MODE=false
VERBOSE=false
DO_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            INTERACTIVE=false
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            AUTO_MODE=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --build)
            DO_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto         자동 모드 (현재 브랜치에서 pull, 사용자 입력 없음)"
            echo "  --interactive  대화식 모드 (브랜치 선택 프롬프트, 기본값)"
            echo "  -v, --verbose  상세 출력"
            echo "  --build        pull 후 analyze/test/DMG/SHA256 빌드까지 실행"
            echo "  --dry-run      checkout/pull/stash/build 없이 선택·원격 정보만 확인"
            echo "  -h, --help     도움말 표시"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CURRENT=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "================================================"
echo "  Kibal (SmartCC IP-PBX) Git Pull"
if [ "$AUTO_MODE" = true ]; then
    echo "  [AUTO MODE] No user input required"
elif [ "$INTERACTIVE" = true ]; then
    echo "  [INTERACTIVE MODE] Branch selector"
fi
echo "================================================"
echo

echo "[1/5] Fetching from all remotes..."
GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o ConnectionAttempts=1" git fetch --all --prune || echo "  WARN: fetch had issues"
echo

# Build branch list
branches=()
while IFS= read -r b; do
    branches+=("$b")
done < <(python3 "$ROOT_DIR/scripts/pick_branch.py" --list 2>/dev/null)

total=${#branches[@]}

# @>-- 2026-09-03: 옵션 기반 브랜치 선택 로직
if [ "$AUTO_MODE" = true ]; then
    # 자동 모드: 현재 브랜치 사용
    BRANCH="$CURRENT"
    if [ "$VERBOSE" = true ]; then
        echo "[AUTO] Using current branch: $BRANCH"
    fi
else
    # 대화식 모드: 사용자 선택
    echo "Available branches (원격/버전/커밋/기능):"
    echo "------------------------------------------------------------"
    for i in "${!branches[@]}"; do
        idx=$((i + 1))
        marker=""
        if [ "${branches[$i]}" = "$CURRENT" ]; then
            marker=" (current)"
        fi
        info=$(python3 "$ROOT_DIR/scripts/pick_branch.py" --info "${branches[$i]}" 2>/dev/null)
        if [ -n "$info" ]; then
            IFS=$'\t' read -r _b rem _tgt ver commit summary <<<"$info"
            printf "  %2d) %-42s [%s] %-12s %s  %s%s\n" "$idx" "${branches[$i]}" "$rem" "$ver" "$commit" "$summary" "$marker"
        else
            echo "  $idx) ${branches[$i]}$marker"
        fi
    done
    echo
    echo -n "Select number [1-$total] (Enter=current): "
    read -r choice

    if [ -z "$choice" ]; then
        BRANCH="$CURRENT"
    elif ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $total ]; then
        echo "  Invalid selection. Using current: $CURRENT"
        BRANCH="$CURRENT"
    else
        BRANCH="${branches[$((choice - 1))]}"
    fi
fi
echo "Selected: $BRANCH"
echo

PULL_REMOTE="origin"
TARGET="$BRANCH"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name "$BRANCH@{upstream}" 2>/dev/null || true)
    if [[ "$UPSTREAM" == */* ]]; then
        PREFIX="${UPSTREAM%%/*}"
        if git remote | grep -qx "$PREFIX"; then
            PULL_REMOTE="$PREFIX"
            TARGET="${UPSTREAM#*/}"
        fi
    fi
elif [[ "$BRANCH" == */* ]]; then
    PREFIX="${BRANCH%%/*}"
    if git remote | grep -qx "$PREFIX"; then
        PULL_REMOTE="$PREFIX"
        TARGET="${BRANCH#*/}"
    fi
fi

show_remote_logs() {
    local ref="$1"
    local files file
    echo "  ---- 최근 원격 로그(다른 작업자 포함) ----"
    files=$(git ls-tree -r --name-only "$ref" -- wiki/07_Logs docs/_작업이력 2>/dev/null \
        | grep -E '\.md$' | sort -r | sed -n '1,3p')
    if [ -n "$files" ]; then
        while IFS= read -r file; do
            echo "  [$file]"
            git show "$ref:$file" 2>/dev/null | tail -8 | sed 's/^/    /'
        done <<<"$files"
    else
        echo "  (원격 로그 파일 없음)"
    fi
    echo "  ---- 로그 커밋 이력 ----"
    git --no-pager log -3 --format='    %h %ad %s' --date=short "$ref" -- wiki/07_Logs docs/_작업이력 2>/dev/null || true
}

if [ "$DRY_RUN" = true ]; then
    echo
    echo "[DRY RUN] checkout/pull/stash/build를 실행하지 않습니다."
    python3 "$ROOT_DIR/scripts/pick_branch.py" --info "$PULL_REMOTE/$TARGET"
    show_remote_logs "$PULL_REMOTE/$TARGET"
    exit 0
fi

echo "[2/5] Current state:"
git status --short
echo

echo "[3/5] Switching to branch: $BRANCH..."

# @>-- 2026-11-17 microdit: 로컬 변경 자동 stash (더티 워크트리 checkout 실패 방지)
STASHED=false
STASH_REF=""
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    STASH_MSG="git-pull.sh auto-stash $(date '+%Y%m%d_%H%M%S')"
    echo "  추적 중인 로컬 변경 감지 → stash 보존: $STASH_MSG"
    if git stash push -m "$STASH_MSG"; then
        STASHED=true
        STASH_REF=$(git rev-parse stash@{0})
    else
        echo "  ERROR: stash 실패 — 작업 트리를 변경하지 않고 중지"
        exit 1
    fi
fi

if git show-ref --verify --quiet "refs/heads/$TARGET"; then
    git checkout "$TARGET" || {
        echo "  ERROR: checkout 실패 ($TARGET). Aborting."
        exit 1
    }
else
    echo "  로컬 브랜치 없음 → $PULL_REMOTE/$TARGET 에서 생성"
    git checkout -b "$TARGET" "$PULL_REMOTE/$TARGET" || {
        echo "  ERROR: Cannot create branch $TARGET from $PULL_REMOTE/$TARGET"
        exit 1
    }
fi
echo

RC=0

echo "[4/5] Pulling from $PULL_REMOTE/$TARGET..."
git pull "$PULL_REMOTE" "$TARGET" || { echo "  WARN: pull had issues"; RC=1; }
echo

echo "[5/5] Sync Status Report"
echo "-----------------------------------------------"
echo "  HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
echo
echo "  Latest commits:"
git --no-pager log --oneline -5 2>/dev/null || echo "  (none)"
echo
echo "  Branch status:"
# @>-- 2026-11-17: 설정된 모든 remote 기준으로 상태 확인 (origin 하드코딩 제거)
for remote in $(git remote); do
    counts=$(git rev-list --left-right --count "$remote/$TARGET...HEAD" 2>/dev/null || true)
    if [ -n "$counts" ]; then
        behind=$(echo "$counts" | cut -f1)
        ahead=$(echo "$counts" | cut -f2)
        echo "  $remote: behind=$behind ahead=$ahead"
    fi
done
echo "-----------------------------------------------"
if [ "$STASHED" = true ]; then
    echo "  STASH: 로컬 변경 보존됨 → 복구: git stash apply $STASH_REF"
fi
if [ $RC -eq 0 ]; then echo "  RESULT: Pull OK"
else echo "  RESULT: Issues detected"
fi

VERSION=$(sed -n 's/^version: //p' macos-client/pubspec.yaml 2>/dev/null | head -1)
EXPECTED_VERSION=$(python3 "$ROOT_DIR/scripts/pick_branch.py" --info "$PULL_REMOTE/$TARGET" 2>/dev/null | cut -f4)
REMOTE_URL=$(git remote get-url "$PULL_REMOTE" 2>/dev/null || echo '-')
HEAD_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo N/A)
REMOTE_COMMIT=$(git rev-parse "$PULL_REMOTE/$TARGET" 2>/dev/null || echo N/A)
DMG_DIR="$ROOT_DIR/macos-client/build/macos/Build/Products/Release"
VERSION_NO_BUILD="${VERSION%%+*}"
DMG="$DMG_DIR/macos_client_v${VERSION_NO_BUILD}.dmg"
SHA="-"
[ -f "$DMG" ] && SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
case "$TARGET" in
  test/*|test-pending-verification) PROMOTE="TEST 검수 중(DEV 승격 금지)" ;;
  *) PROMOTE="기능/DEV 라인(승격 상태 확인 필요)" ;;
esac
NAS=$(nc -z -G 2 192.168.11.2 4949 2>/dev/null && echo "연결 가능" || echo "SKIP(SSH 4949 timeout)")
BUILD_RESULT="실행 안 함"

if [ "$DO_BUILD" = true ]; then
    if [ $RC -ne 0 ]; then
        BUILD_RESULT="pull 실패로 생략"
    elif [ -n "$EXPECTED_VERSION" ] && [ "$EXPECTED_VERSION" != "-" ] && [ "$VERSION" != "$EXPECTED_VERSION" ]; then
        BUILD_RESULT="로컬/원격 버전 불일치로 생략"
        RC=1
    else
        echo
        echo "[6/5] Build on $TARGET (버전 ${VERSION:-N/A})..."
        if (
          cd "$ROOT_DIR/macos-client" || exit 1
          flutter analyze && flutter test && \
          ./scripts/release_macos.sh --no-bump --skip-tests && \
          codesign --verify --deep --strict build/macos/Build/Products/Release/macos_client.app && \
          shasum -a 256 "build/macos/Build/Products/Release/macos_client_v${VERSION_NO_BUILD}.dmg"
        ); then
            BUILD_RESULT="성공"
        else
            BUILD_RESULT="실패"
            RC=1
        fi
        VERSION=$(sed -n 's/^version: //p' macos-client/pubspec.yaml 2>/dev/null | head -1)
        VERSION_NO_BUILD="${VERSION%%+*}"
        DMG="$DMG_DIR/macos_client_v${VERSION_NO_BUILD}.dmg"
        SHA="-"
        [ -f "$DMG" ] && SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
    fi
fi

echo
echo "================ 발행 보고 (자동 생성) ================"
echo "  1. 저장소: $ROOT_DIR"
echo "  2. 작업 브랜치: $TARGET"
echo "  3. 원격: $PULL_REMOTE ($REMOTE_URL)"
echo "  4. 푸시 원격 브랜치: $PULL_REMOTE/$TARGET"
echo "  5. 커밋: ${HEAD_COMMIT:0:8} (원격 ${REMOTE_COMMIT:0:8})"
echo "  6. 버전: ${VERSION:-N/A} (원격 기대값 ${EXPECTED_VERSION:-N/A})"
if [ -n "$EXPECTED_VERSION" ] && [ "$EXPECTED_VERSION" != "-" ] && [ "$VERSION" != "$EXPECTED_VERSION" ]; then
    echo "  WARN: 로컬/원격 버전 불일치 — 빌드·승격을 중단하고 원격 최신을 확인하세요."
fi
if [ -f "$DMG" ]; then
    echo "  7. DMG/SHA256: $DMG | ${SHA:-N/A}"
else
    echo "  7. DMG/SHA256: 없음(빌드 전)"
fi
echo "  빌드 결과: $BUILD_RESULT"
echo "  승격 상태: $PROMOTE"
echo "  NAS dev/prd: $NAS"
echo "  pull 안내: git checkout -b $TARGET $PULL_REMOTE/$TARGET"
echo
show_remote_logs "$PULL_REMOTE/$TARGET"
echo "==================================================="

echo
echo "  NAS deploy (if needed):"
echo "    ssh nas2 \"cd /var/services/homes/atom/SmartCC_Kibal-Client && git pull $PULL_REMOTE $TARGET\""
echo

exit $RC
