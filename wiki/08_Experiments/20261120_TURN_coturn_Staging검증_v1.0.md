# TURN/coturn Staging 검증 보고서

| 항목 | 내용 |
|------|------|
| 작성일 | 2026-11-20 |
| 버전 | v1.0 |
| 상태 | **Staging 완료** (운영 포트 개방 전) |
| 결정 | [[wiki/05_Decisions/ADR-010_TURN_coturn_20261120]] (서버 wiki) |
| 계획 | [[wiki/01_Projects/20261120_TURN_coturn_구축계획서_v1.0]] |
| 클라이언트 | `v0.0.53` (SHA256 `51f775ba…`) |

---

## 1. 구현 내용

| 계층 | 변경 |
|------|------|
| 서버 | `deploy/dev/turn/{turnserver.conf.template,entrypoint.sh}` 추가, compose에 `kibal-dev-turn` 서비스(bridge + publish 3478/5349/relay), `.env`에 TURN_SECRET/REALM/EXTERNAL_IP/TTL 추가 |
| OPS | `routes.py` `/api/client/config`가 시간제 HMAC `turn` 객체 반환(`<expiry>:<ext>`, base64 HMAC-SHA1), `config.py`에 OPS_TURN_* 추가 |
| 클라이언트 | `SipConfig.turn`, `ServerConfig.turn` 추가, 외부 프로필만 OPS turn 값 유지, `sip_client.dart`가 `UaSettings.iceServers`에 자격증명 전달, `FORCE_RELAY` dart-define 지원 |
| 진단도구 | `tool/turn_probe.dart` 추가 — relay 후보 직접 수집 확인 |

---

## 2. 검증 결과

| 항목 | 결과 | 근거 |
|------|------|------|
| OPS 토큰 발급 | PASS | `/api/client/config`에 `turn.urls/username/credential/ttl` 존재 |
| coturn 기동 | PASS | `relay 0.0.0.0 initialization done`, 3478/5349/relay 리스닝 |
| relay 후보 수집 | PASS | `turn_probe`: `candidate:... typ relay raddr 0.0.0.0` 3개 |
| 강제 RELAY 1:1 | **PASS** | `FORCE_RELAY=true`, `>>> RESULT: CALL_OK`, ICE Connected/Completed |
| 강제 RELAY 3자 | **PASS** | `>>> RESULT: CONFERENCE_OK`, 3자 모두 ICE 완료 |
| 일반 통화 회귀 | PASS | FORCE_RELAY 없이 `CALL_OK` |
| 정적 검사 | PASS | `flutter analyze` 0 / `flutter test` 17/17 |

---

## 3. 제약 및 발견 사항

- IPTime 포트포워딩(3478/5349/relay)은 **하지 않음**. Staging은 내부 호스트(`127.0.0.1:3478`, `192.168.11.5:3478`)만 사용.
- coturn은 bridge + publish로 구성. Docker Desktop `network_mode: host`에서는 macOS 호스트가 포트에 접근할 수 없어 relay socket 생성(508) 실패가 발생했다. bridge + publish로 해결.
- `relay-ip`를 지정하지 않고 `external-ip=<공인>/<사설>`만 사용. relay 광고 주소는 공인 IP로 표시된다.
- relay 대역 `49152-49252/udp`는 RTP `10000-10200`과 비중첩.
- Staging 중 OPS 8091이 간헐적으로 hang(내부 127은 200, LAN IP 000)하는 현상 재발 → 컨테이너 재시작으로 복구, healthcheck timeout/retries 완화 적용. **근본 원인은 미해결**.

---

## 4. 운영 배포 전 승인 필요

1. IPTime1에 3478 TCP/UDP, 5349 TCP, relay 49152-49252 UDP 포워딩.
2. `TURN_SECRET` 보관/교체 정책, TTL(현재 3600초) 확정.
3. Synology 인증서 만료(2026-12-31) 갱신 시 `turns:`도 함께 재적재.
4. 공인 IP 변경 시 DDNS + coturn `external-ip` + Asterisk `media_address` 동시 갱신 스크립트.

---

## 5. 관련 문서

- [[wiki/08_Experiments/20261120_외부망_종단간검증_v1.0]]
- [[wiki/08_Experiments/20261120_에이전트_자체테스트_종합_v1.0]]
- [[wiki/07_Logs/20261120]]
