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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto         자동 모드 (현재 브랜치에서 pull, 사용자 입력 없음)"
            echo "  --interactive  대화식 모드 (브랜치 선택 프롬프트, 기본값)"
            echo "  -v, --verbose  상세 출력"
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
git fetch --all --prune || echo "  WARN: fetch had issues"
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
    echo "Available branches:"
    echo "----------------------"
    for i in "${!branches[@]}"; do
        idx=$((i + 1))
        marker=""
        if [ "${branches[$i]}" = "$CURRENT" ]; then
            marker=" (current)"
        fi
        echo "  $idx) ${branches[$i]}$marker"
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

echo "[2/5] Current state:"
git status --short
echo

echo "[3/5] Switching to branch: $BRANCH..."

# @>-- 2026-11-17 microdit: remote-tracking 선택(github/foo) → 로컬 브랜치명/remote 분리
PULL_REMOTE="github"
TARGET="$BRANCH"
if [[ "$BRANCH" == */* ]]; then
    PREFIX="${BRANCH%%/*}"
    if git remote | grep -qx "$PREFIX"; then
        PULL_REMOTE="$PREFIX"
        TARGET="${BRANCH#*/}"
    fi
fi

# @>-- 2026-11-17 microdit: 로컬 변경 자동 stash (더티 워크트리 checkout 실패 방지)
STASHED=false
if [ -n "$(git status --porcelain)" ]; then
    STASH_MSG="git-pull.sh auto-stash $(date '+%Y%m%d_%H%M%S')"
    echo "  로컬 변경 감지 → stash 보존: $STASH_MSG"
    if git stash push -u -m "$STASH_MSG"; then
        STASHED=true
    else
        echo "  WARN: stash 실패 — checkout 계속 시도"
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
    echo "  STASH: 로컬 변경 보존됨 → 복구: git stash pop"
fi
if [ $RC -eq 0 ]; then echo "  RESULT: Pull OK"
else echo "  RESULT: Issues detected"
fi
echo
echo "  NAS deploy (if needed):"
echo "    ssh nas2 \"cd /var/services/homes/atom/SmartCC_Kibal-Client && git pull $PULL_REMOTE $TARGET\""
echo

exit $RC
