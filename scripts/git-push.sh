#!/bin/bash
# Kibal (SmartCC IP-PBX) Git Push
# 전체 브랜치 최신 커밋 탐지 + 대화형 브랜치/remote 선택 + Push (macOS/Linux)
# @>-- 2026-11-17 microdit: 신규 작성 (git-pull.sh 대응), auto-stash 내장
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

INTERACTIVE=true
AUTO_MODE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO_MODE=true; INTERACTIVE=false; shift ;;
        --interactive) INTERACTIVE=true; AUTO_MODE=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto          현재 브랜치를 모든 remote에 push (입력 없음)"
            echo "  --interactive   브랜치/remote 대화형 선택 (기본값)"
            echo "  --dry-run       push 없이 탐지/선택만 수행"
            echo "  -h, --help      도움말 표시"
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1 ;;
    esac
done

CURRENT=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "================================================"
echo "  Kibal (SmartCC IP-PBX) Git Push"
if [ "$AUTO_MODE" = true ]; then
    echo "  [AUTO MODE] 현재 브랜치 → 모든 remote"
else
    echo "  [INTERACTIVE MODE] 브랜치 선택"
fi
echo "================================================"
echo

echo "[1/5] Fetching from all remotes..."
git fetch --all --prune || echo "  WARN: fetch had issues"
echo

# ── 전체 ref 최신 커밋 탐지 ──
REF_FMT='%(refname:short)|%(committerdate:format:%Y-%m-%d %H:%M)|%(objectname:short)|%(subject)'
names=(); dates=(); hashes=(); subjects=()
while IFS= read -r line; do
    IFS='|' read -r n d h s <<< "$line"
    names+=("$n"); dates+=("$d"); hashes+=("$h"); subjects+=("$s")
done < <(git for-each-ref --sort=-committerdate --format="$REF_FMT" refs/heads refs/remotes 2>/dev/null | grep -v '/HEAD$')

LATEST_HASH="${hashes[0]:-N/A}"
LATEST_NAME="${names[0]:-N/A}"
LATEST_DATE="${dates[0]:-N/A}"
LATEST_SUBJ="${subjects[0]:-N/A}"

echo "[2/5] 전체 브랜치 최신 커밋"
echo "-----------------------------------------------"
echo "  최신: $LATEST_HASH  ($LATEST_DATE)  $LATEST_NAME"
echo "  내용: $LATEST_SUBJ"
echo "  동일 커밋 ref:"
for i in "${!names[@]}"; do
    if [ "${hashes[$i]}" = "$LATEST_HASH" ]; then
        echo "    - ${names[$i]}"
    fi
done
echo "-----------------------------------------------"
echo

# ── 브랜치 선택 ──
BRANCH="$CURRENT"
if [ "$AUTO_MODE" = true ]; then
    echo "[3/5] AUTO: 현재 브랜치 사용 → $BRANCH"
else
    echo "[3/5] Push할 브랜치 선택"
    for i in "${!names[@]}"; do
        idx=$((i + 1))
        marker=""
        if [ "${names[$i]}" = "$CURRENT" ]; then marker=" (current)"; fi
        if [ "${hashes[$i]}" = "$LATEST_HASH" ]; then marker="$marker (LATEST)"; fi
        echo "  $idx) ${names[$i]}  [${dates[$i]} ${hashes[$i]}]${marker}"
    done
    echo
    echo -n "Select number [1-${#names[@]}] (Enter=current): "
    read -r choice
    if [ -n "$choice" ] && [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
        BRANCH="${names[$((choice - 1))]}"
    fi
fi
echo "Selected: $BRANCH"
echo

# remote-tracking 선택 → 로컬 브랜치명/remote 분리
PUSH_REMOTE="github"
TARGET="$BRANCH"
if [[ "$BRANCH" == */* ]]; then
    PREFIX="${BRANCH%%/*}"
    if git remote | grep -qx "$PREFIX"; then
        PUSH_REMOTE="$PREFIX"
        TARGET="${BRANCH#*/}"
    fi
fi

# ── auto-stash (더티 워크트리 해결) ──
STASHED=false
if [ -n "$(git status --porcelain)" ]; then
    STASH_MSG="git-push.sh auto-stash $(date '+%Y%m%d_%H%M%S')"
    echo "[4/5] 로컬 변경 감지 → stash 보존: $STASH_MSG"
    echo "      (stash된 변경은 push에 포함되지 않습니다 — 커밋 후 재실행하세요)"
    if git stash push -u -m "$STASH_MSG"; then
        STASHED=true
    else
        echo "  WARN: stash 실패 — 계속 진행"
    fi
else
    echo "[4/5] 작업트리 clean — stash 불필요"
fi

if [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" != "$TARGET" ]; then
    git checkout "$TARGET" || { echo "  ERROR: checkout 실패 ($TARGET)"; exit 1; }
fi
echo

# ── 대상 remote 결정 ──
CANDIDATES=()
for r in $(git remote); do
    if git show-ref --verify --quiet "refs/remotes/$r/$TARGET"; then
        CANDIDATES+=("$r")
    fi
done
if [ ${#CANDIDATES[@]} -eq 0 ]; then
    CANDIDATES=("$PUSH_REMOTE")
fi

REMOTES=("${CANDIDATES[@]}")
if [ "$AUTO_MODE" != true ]; then
    echo "  대상 remote:"
    echo "    a) all (${CANDIDATES[*]})"
    for i in "${!CANDIDATES[@]}"; do
        echo "    $((i + 1))) ${CANDIDATES[$i]}"
    done
    echo -n "  선택 (Enter=all, 번호=해당 remote): "
    read -r rsel
    if [ -n "$rsel" ] && [[ "$rsel" =~ ^[0-9]+$ ]] && [ "$rsel" -ge 1 ] && [ "$rsel" -le "${#CANDIDATES[@]}" ]; then
        REMOTES=("${CANDIDATES[$((rsel - 1))]}")
    fi
fi

remote_reachable() {
    local r="$1" url host port
    url=$(git remote get-url --push "$r" 2>/dev/null)
    if [[ "$url" == ssh://* ]]; then
        host=$(echo "$url" | sed -E 's#ssh://([^@]*@)?([^:/]+).*#\2#')
        port=$(echo "$url" | sed -nE 's#ssh://([^@]*@)?[^:/]+:([0-9]+)/.*#\2#p'); port=${port:-22}
        if ! nc -z -G 3 "$host" "$port" >/dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}

echo "[5/5] Pushing $TARGET → ${REMOTES[*]}"
if [ "$DRY_RUN" = true ]; then
    echo "  (dry-run — 실제 push 생략)"
else
    OK=0; FAIL=0
    for r in "${REMOTES[@]}"; do
        if ! remote_reachable "$r"; then
            echo "  SKIP: $r 접근 경로 없음 (NAS 대역 미도달)"
            FAIL=$((FAIL + 1))
            continue
        fi
        if GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o BatchMode=yes" git push "$r" "$TARGET"; then
            echo "  $r: OK"; OK=$((OK + 1))
        else
            echo "  WARN: $r push failed (offline or rejected)"
            FAIL=$((FAIL + 1))
        fi
    done
    echo "  Push: $OK OK, $FAIL failed/skipped"
fi
echo

echo "================================================"
echo "  HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
for r in $(git remote); do
    counts=$(git rev-list --left-right --count "$r/$TARGET...HEAD" 2>/dev/null || echo "0 0")
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo "$counts" | awk '{print $2}')
    echo "  $r: behind=$behind ahead=$ahead"
done
if [ "$STASHED" = true ]; then
    echo "  STASH: 로컬 변경 보존됨 → 복구: git stash pop"
fi
echo "================================================"
