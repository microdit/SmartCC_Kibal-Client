#!/bin/bash
# 원격 오디오 복구(v0.0.5) 실기 검증용 서버 증거 수집
# 사용: ./scripts/capture_remote_audio.sh [duration_sec] [room]
#   기본 duration=600(10분), room=6000
# 동작:
#   1) pjsip logger / rtp debug ON
#   2) duration 동안 10초 간격으로 confbridge list / channelstats 스냅샷
#   3) 종료 시 logger/rtp debug OFF, docker logs 수집
# 산출물: docs/_작업이력/evidence/YYYYMMDD-remote-audio-HHMMSS/
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER="${ASTERISK_CONTAINER:-kibal-dev-asterisk}"
DURATION="${1:-600}"
ROOM="${2:-6000}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTDIR="$ROOT_DIR/docs/_작업이력/evidence/${STAMP}-remote-audio"
mkdir -p "$OUTDIR"

# 컨테이너는 Asterisk를 `-C /run/asterisk/asterisk.conf`로 실행한다.
# CLI도 동일 config를 지정해야 경고 없이 올바른 ctl 소켓에 연결된다.
# (경로가 다른 이미지면 ASTERISK_CONF 환경변수로 재정의)
ASTERISK_BIN="${ASTERISK_BIN:-/usr/sbin/asterisk}"
ASTERISK_CONF="${ASTERISK_CONF:-/run/asterisk/asterisk.conf}"
AST() { docker exec "$CONTAINER" "$ASTERISK_BIN" -C "$ASTERISK_CONF" -rx "$1" 2>&1; }

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "ERROR: container '$CONTAINER' not running" >&2
  exit 1
fi

START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ">>> capture start container=$CONTAINER room=$ROOM duration=${DURATION}s"
echo ">>> outdir: $OUTDIR"

AST "pjsip set logger on"  > "$OUTDIR/00_logger_on.txt"
AST "rtp set debug on"     >> "$OUTDIR/00_logger_on.txt"

cleanup() {
  echo ">>> capture stop"
  AST "rtp set debug off"      >  "$OUTDIR/99_logger_off.txt"
  AST "pjsip set logger off"   >> "$OUTDIR/99_logger_off.txt"
  AST "confbridge list $ROOM"  >  "$OUTDIR/98_confbridge_final.txt"
  AST "pjsip show channelstats" > "$OUTDIR/97_channelstats_final.txt"
  docker logs --since "$START_ISO" "$CONTAINER" > "$OUTDIR/90_docker_during_test.log" 2>&1 || true
  echo ">>> artifacts:"
  ls -lh "$OUTDIR"
}
trap cleanup EXIT INT TERM

ELAPSED=0
while [ "$ELAPSED" -lt "$DURATION" ]; do
  N=$((ELAPSED / 10))
  TS="$(date +%H%M%S)"
  {
    echo "=== t=${ELAPSED}s at $TS ==="
    AST "confbridge list $ROOM"
    echo "--- channelstats ---"
    AST "pjsip show channelstats"
  } > "$OUTDIR/snapshot_$(printf '%03d' "$N")_${TS}.txt" 2>&1
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done
