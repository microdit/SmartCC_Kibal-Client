#!/bin/bash
# Kibal (SmartCC IP-PBX) Git Sync
# Commit + Push All Remotes + Auto Log
# Version: 2.0 (macOS/Linux/NAS)
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Python path
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then echo "ERROR: no python found"; exit 1; fi

AUTO=0
STATUS=0
COMMIT_MSG=""
# PRD(NAS) 배포 모드: ask(대화형 확인) | yes(--deploy 자동) | no(--no-deploy 생략)
DEPLOY_MODE="ask"

# ── Functions ──

log_result() {
    local status="$1" rc="$2"
    local log_script="$ROOT_DIR/scripts/log.py"
    if [ -f "$log_script" ]; then
        "$PYTHON" "$log_script" "git-sync" "$status" "0" --desc "branch=$BRANCH rc=$rc" 2>/dev/null || true
    fi
}

report() {
    echo
    echo "[4/4] Sync Status Report"
    echo "-----------------------------------------------"
    echo "  HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
    echo
    echo "  Recent commits:"
    git --no-pager log --oneline -5 2>/dev/null || echo "  (none)"
    echo
    echo "  Remotes:"
    git remote -v 2>/dev/null || true
    echo
    echo "  [Remote Sync]"
    for r in $(git remote 2>/dev/null); do
        counts=$(git rev-list --left-right --count "$r/$BRANCH...HEAD" 2>/dev/null || echo "0 0")
        behind=$(echo "$counts" | awk '{print $1}')
        ahead=$(echo "$counts" | awk '{print $2}')
        if [ "$behind" = "0" ] && [ "$ahead" = "0" ]; then
            echo "    $r: in sync"
        elif [ "$behind" != "0" ]; then
            echo "    $r: behind=$behind ahead=$ahead"
        else
            echo "    $r: ahead=$ahead"
        fi
    done
    echo "-----------------------------------------------"
    if [ "$RC" = "0" ]; then echo "  RESULT: All OK"
    elif [ "$RC" = "2" ]; then echo "  RESULT: Nothing to commit"
    else echo "  RESULT: FAILED - see errors above"
    fi
    echo "================================================"
}

push_remote() {
    local remote="$1" branch="$2"
    echo "    Pushing to $remote/$branch..."
    if git push "$remote" "$branch" 2>/dev/null; then
        echo "    $remote: OK"
        return 0
    else
        echo "    WARN: $remote push failed (offline or misconfigured)"
        return 1
    fi
}

# ── Argument parsing ──

for arg in "$@"; do
    case "$arg" in
        --auto) AUTO=1 ;;
        --status) STATUS=1 ;;
        --deploy) DEPLOY_MODE="yes" ;;
        --no-deploy) DEPLOY_MODE="no" ;;
        --help|-h)
            echo "Usage: $0 \"commit message\""
            echo "       $0 --auto       (auto-generate from log)"
            echo "       $0 --auto --deploy      (sync + PRD 배포 자동)"
            echo "       $0 --auto --no-deploy   (sync, 배포 묻지 않음)"
            echo "       $0 --status     (show sync status)"
            exit 0 ;;
    esac
done

# Remove flags from COMMIT_MSG
for arg in "$@"; do
    case "$arg" in
        --*) ;;
        *) COMMIT_MSG="${COMMIT_MSG:-}$arg " ;;
    esac
done
COMMIT_MSG="${COMMIT_MSG% }"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# ── Status mode ──
if [ "$STATUS" = "1" ]; then
    HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
    DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    echo "================================================"
    echo "  SmartCC_Kibal (Kibal IP-PBX) Git Status"
    echo "  $(date)"
    echo "================================================"
    echo
    echo "  Branch: $BRANCH"
    echo "  HEAD:   $HASH"
    echo
    if [ "$DIRTY" = "0" ]; then echo "  Tree: clean"; else echo "  Tree: $DIRTY pending"; fi
    echo
    echo "  [Remote Sync]"
    for r in $(git remote 2>/dev/null); do
        counts=$(git rev-list --left-right --count "$r/$BRANCH...HEAD" 2>/dev/null || echo "0 0")
        behind=$(echo "$counts" | awk '{print $1}')
        ahead=$(echo "$counts" | awk '{print $2}')
        if [ "$behind" = "0" ] && [ "$ahead" = "0" ]; then
            echo "    $r: in sync"
        elif [ "$behind" != "0" ]; then
            echo "    $r: behind=$behind ahead=$ahead"
        else
            echo "    $r: ahead=$ahead"
        fi
    done
    echo
    echo "  [Recent Commits]"
    git --no-pager log --oneline -5 2>/dev/null || echo "  (none)"
    echo
    echo "  [Quick Actions]"
    if [ "$DIRTY" != "0" ]; then echo "    -> bash scripts/git-sync.sh --auto"; fi
    echo "================================================"
    exit 0
fi

# ── Usage check ──
if [ "$AUTO" = "0" ] && [ -z "$COMMIT_MSG" ]; then
    echo "Usage: $0 \"commit message\""
    echo "       $0 --auto       (auto-generate from log)"
    echo "       $0 --auto --deploy      (sync + PRD 배포 자동)"
    echo "       $0 --auto --no-deploy   (sync, 배포 묻지 않음)"
    echo "       $0 --status     (show sync status)"
    exit 1
fi

RC=0

REMOTES=$(git remote 2>/dev/null | tr '\n' ' ')
echo "================================================"
echo "  SmartCC_Kibal (Kibal IP-PBX) Git Sync"
echo "  Branch: $BRANCH"
echo "  Remotes: $REMOTES"
echo "================================================"
echo

echo "[1/4] Staging all changes..."
git add -A || { echo "FAILED: git add"; exit 1; }
echo "  ok"
echo

if [ "$AUTO" = "1" ]; then
    echo "[2/4] Generating commit message..."
    if [ -f "$ROOT_DIR/scripts/generate-commit-msg.py" ]; then
        rm -f ".git/AUTO_COMMIT_MSG"
        "$PYTHON" "$ROOT_DIR/scripts/generate-commit-msg.py" || echo "  WARN: auto-generator had issues"
    fi
    if [ -f ".git/AUTO_COMMIT_MSG" ]; then
        FIRST_LINE=$(head -1 ".git/AUTO_COMMIT_MSG")
        echo "  Title: $FIRST_LINE"
        git commit -F ".git/AUTO_COMMIT_MSG" || {
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 1 ]; then echo "  Nothing to commit - all clean."; RC=2
            else echo "FAILED: git commit"; exit 1; fi
        }
    else
        echo "  Auto-generator not available. Using date-based message."
        git commit -m "chore: $(date '+%Y-%m-%d %H:%M') sync" || {
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 1 ]; then echo "  Nothing to commit - all clean."; RC=2
            else echo "FAILED: git commit"; exit 1; fi
        }
    fi
else
    echo "[2/4] Committing: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" || {
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 1 ]; then echo "  Nothing to commit - all clean."; RC=2
        else echo "FAILED: git commit"; exit 1; fi
    }
fi
echo

if [ $RC -ne 2 ]; then
    echo "[3/4] Pushing to all remotes..."
    PUSH_OK=0
    PUSH_FAIL=0
    for r in $(git remote 2>/dev/null); do
        if push_remote "$r" "$BRANCH"; then
            PUSH_OK=$((PUSH_OK + 1))
        else
            PUSH_FAIL=$((PUSH_FAIL + 1))
        fi
    done
    echo "  Push complete: $PUSH_OK OK, $PUSH_FAIL failed"
    echo
fi

report

# ── [5/5] PRD(NAS) 배포 (선택) ──
# DEPLOY_MODE: ask(대화형 확인) / yes(--deploy 자동) / no(--no-deploy 생략)
# - 동기화 실패(RC 0/2 아님)면 배포 생략
# - 비대화형 실행(터미널 없음) 시 기본 생략, --deploy로 강제
deploy_to_prd() {
    echo
    echo "[5/5] PRD(NAS) 배포"
    echo "-----------------------------------------------"
    if [ -f "$ROOT_DIR/deploy_to_nas_v2.sh" ]; then
        bash "$ROOT_DIR/deploy_to_nas_v2.sh"
        return $?
    fi
    echo "  ERROR: deploy_to_nas_v2.sh not found"
    return 1
}

DEPLOY_RC=""
case "$DEPLOY_MODE" in
    no)
        : # --no-deploy: 배포 생략
        ;;
    yes)
        if [ "$RC" = "0" ] || [ "$RC" = "2" ]; then
            deploy_to_prd
            DEPLOY_RC=$?
        else
            echo "  --deploy 요청됐으나 동기화 실패(RC=$RC)로 배포 건너뜀"
        fi
        ;;
    ask)
        if [ "$RC" != "0" ] && [ "$RC" != "2" ]; then
            echo "  (동기화 실패 — 배포 건너뜀)"
        elif [ ! -t 0 ]; then
            echo "  (비대화형 실행 — 배포 생략. 배포하려면 --deploy 추가)"
        else
            if [ "$RC" = "2" ]; then echo "  (커밋할 변경 없음 — 현재 로컬 상태 기준 배포 가능)"; fi
            echo
            read -r -p "  PRD(NAS)에 배포하시겠습니까? [y/N] " _deploy_ans
            case "$_deploy_ans" in
                [yY]|[yY][eE][sS])
                    deploy_to_prd
                    DEPLOY_RC=$?
                    ;;
                *)
                    echo "  배포 생략."
                    ;;
            esac
        fi
        ;;
esac

log_result "PASSED" "$RC"
[ "$RC" != "0" ] && log_result "FAILED" "$RC"

if [ -n "$DEPLOY_RC" ] && [ "$DEPLOY_RC" != "0" ]; then
    echo "  WARN: 배포 실패 (rc=$DEPLOY_RC) — 동기화는 정상 완료, 원격 수동 점검 필요"
fi

exit $RC
