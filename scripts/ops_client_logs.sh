#!/bin/bash
# 클라이언트 로그 조회 도구 (OPS 콘솔)
# 사용:
#   ./scripts/ops_client_logs.sh list
#   ./scripts/ops_client_logs.sh tail <내선> [줄수]
#   ./scripts/ops_client_logs.sh follow <내선> [줄수]   (host에서 docker tail -f)
# 환경변수: OPS_URL(기본 http://localhost:8091), OPS_CLIENT_KEY(기본 dev 공유키)
set -uo pipefail

URL="${OPS_URL:-http://localhost:8091}"
KEY="${OPS_CLIENT_KEY:-dev-kibal-clients-2026}"
CMD="${1:-list}"
EXT="${2:-}"
N="${3:-200}"

case "$CMD" in
  list)
    curl -s "$URL/api/client-logs" -H "X-Client-Key: $KEY" --max-time 8 \
      | python3 -c 'import sys,json
d=json.load(sys.stdin)["data"]
for c in d.get("clients",[]):
    print(c["extension"], c["bytes"], str(c["lines"])+" lines")'
    ;;
  tail)
    if [ -z "$EXT" ]; then echo "usage: $0 tail <내선> [줄수]"; exit 1; fi
    curl -s "$URL/api/client-logs?extension=$EXT&tail=$N" -H "X-Client-Key: $KEY" --max-time 8 \
      | python3 -c 'import sys,json; print("\n".join(json.load(sys.stdin)["data"].get("lines") or []))'
    ;;
  follow)
    if [ -z "$EXT" ]; then echo "usage: $0 follow <내선> [줄수]"; exit 1; fi
    FILE="/var/lib/kibal-ops/client-logs/${EXT}.log"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "kibal-dev-ops"; then
      docker exec kibal-dev-ops tail -n "${N}" -f "$FILE"
    else
      echo "kibal-dev-ops 컨테이너가 없습니다. docker를 확인하세요." >&2
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 {list|tail <ext> [n]|follow <ext> [n]}"
    exit 1
    ;;
esac
