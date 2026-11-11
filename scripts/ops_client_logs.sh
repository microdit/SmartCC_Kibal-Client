#!/bin/bash
# 클라이언트 로그 조회 도구 (OPS 콘솔) — 에이전트/개발자용
# 클라이언트(DMG 앱)가 로그를 자동 업로드하며, 이 스크립트는 서버에 쌓인 로그를 읽기만 한다.
# 사용:
#   ./scripts/ops_client_logs.sh list                     # 내선별 수신 현황(모드/버전/마지막 수신)
#   ./scripts/ops_client_logs.sh tail <내선> [줄수]       # 최근 로그
#   ./scripts/ops_client_logs.sh grep <내선> <검색어> [줄수]
#   ./scripts/ops_client_logs.sh follow <내선> [주기초]   # 증분 실시간 추적(API after 기반)
# 환경변수: OPS_URL(기본 http://localhost:8091), OPS_CLIENT_KEY(기본 dev 공유키)
set -uo pipefail

URL="${OPS_URL:-http://localhost:8091}"
KEY="${OPS_CLIENT_KEY:-dev-kibal-clients-2026}"
CMD="${1:-list}"
EXT="${2:-}"

api() {
  curl -s --max-time 8 -H "X-Client-Key: $KEY" "$URL/api/client-logs?$1"
}

read -r -d '' PY_LIST <<'EOF'
import sys, json, time
d = json.load(sys.stdin)["data"]
now = time.time()
for c in d.get("clients", []):
    seen = c.get("last_seen")
    ago = "-" if not seen else "%ds ago" % int(now - seen)
    print("%-8s lines=%-6s bytes=%-8s last=%-10s mode=%s app=%s host=%s" % (
        c.get("extension"), c.get("lines"), c.get("bytes"), ago,
        c.get("mode") or "-", c.get("app_version") or "-", c.get("host") or "-"))
EOF

read -r -d '' PY_LINES <<'EOF'
import sys, json
for line in json.load(sys.stdin)["data"].get("lines") or []:
    print(line)
EOF

read -r -d '' PY_TOTAL <<'EOF'
import sys, json
print(json.load(sys.stdin)["data"].get("total") or 0)
EOF

case "$CMD" in
  list)
    api "tail=1" | python3 -c "$PY_LIST"
    ;;
  tail)
    [ -z "$EXT" ] && { echo "usage: $0 tail <내선> [줄수]"; exit 1; }
    api "extension=$EXT&tail=${3:-200}" | python3 -c "$PY_LINES"
    ;;
  grep)
    if [ -z "$EXT" ] || [ -z "${3:-}" ]; then echo "usage: $0 grep <내선> <검색어> [줄수]"; exit 1; fi
    Q=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$3")
    api "extension=$EXT&tail=${4:-500}&q=$Q" | python3 -c "$PY_LINES"
    ;;
  follow)
    [ -z "$EXT" ] && { echo "usage: $0 follow <내선> [주기초]"; exit 1; }
    INTERVAL="${3:-2}"
    AFTER=$(api "extension=$EXT&tail=1" | python3 -c "$PY_TOTAL")
    echo "--- follow $EXT (line $AFTER 이후, ${INTERVAL}s 주기, Ctrl+C 종료) ---" >&2
    while true; do
      OUT=$(api "extension=$EXT&tail=500&after=$AFTER")
      if [ -n "$OUT" ]; then
        printf '%s' "$OUT" | python3 -c "$PY_LINES"
        TOTAL=$(printf '%s' "$OUT" | python3 -c "$PY_TOTAL")
        # 서버 파일 로테이션(줄 수 감소) 시 처음부터 다시
        if [ "$TOTAL" -lt "$AFTER" ]; then AFTER=0; else AFTER="$TOTAL"; fi
      fi
      sleep "$INTERVAL"
    done
    ;;
  *)
    echo "usage: $0 {list|tail <ext> [n]|grep <ext> <q> [n]|follow <ext> [sec]}"
    exit 1
    ;;
esac
