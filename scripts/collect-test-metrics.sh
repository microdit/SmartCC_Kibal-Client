#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPS_URL="${OPS_URL:-http://192.168.11.5:8091}"
EXT="${1:-1102}"
PHASE="${2:-current}"
COUNT="${3:-10}"
DATE_COMPACT="$(date +%Y%m%d)"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
OUT="$ROOT/wiki/08_Experiments/${DATE_COMPACT}_네트워크전환_품질검증_v1.0.md"

mkdir -p "$(dirname "$OUT")"

if [ ! -f "$OUT" ]; then
  {
    printf '# 네트워크 전환 품질 검증 수집\n\n'
    printf '| 항목 | 내용 |\n|------|------|\n'
    printf '| **작성일** | %s |\n' "$DATE_COMPACT"
    printf '| **대상** | 6700 회의실 / 단말 `%s` |\n' "$EXT"
    printf '| **수집 명령** | `ops_client_logs.sh grep <ext> "video summary" / "media summary"` |\n\n'
  } > "$OUT"
fi

{
  printf '\n## %s — %s\n\n' "$STAMP" "$PHASE"
  printf '### video summary\n\n```text\n'
  OPS_URL="$OPS_URL" "$ROOT/scripts/ops_client_logs.sh" grep "$EXT" 'video summary' "$COUNT" 2>&1
  printf '```\n\n'
  printf '### media summary\n\n```text\n'
  OPS_URL="$OPS_URL" "$ROOT/scripts/ops_client_logs.sh" grep "$EXT" 'media summary' "$COUNT" 2>&1
  printf '```\n'
} >> "$OUT"

printf '>>> 수집 완료: %s (phase=%s)\n' "$OUT" "$PHASE"
