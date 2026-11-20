# TURN/coturn 구축 계획서 (Staging)

| 항목 | 내용 |
|------|------|
| 작성일 | 2026-11-20 |
| 버전 | v1.0 |
| 결정 | [[wiki/05_Decisions/ADR-010_TURN_coturn_20261120]] (서버 wiki) |
| 범위 | Mac Pro DEV Docker + 내부 강제 RELAY probe |

---

## 1. 구성

| 구성요소 | 값 |
|----------|----|
| 이미지 | `coturn/coturn:4.6.2-alpine` |
| 컨테이너 | `kibal-dev-turn` (host network) |
| 인증 | `use-auth-secret`, HMAC-SHA1, TTL 3600초 |
|Realm | `appletreeda.synology.me` |
| 포트 | 3478 TCP/UDP, 5349 TCP, relay 49152-49252 UDP |
| 인증서 | `deploy/dev/certs/fullchain.pem` + `privkey.pem` 재사용 |

---

## 2. 구현 순서

1. 서버: `deploy/dev/turn/` 템플릿/엔트리포인트, compose 서비스, `.env` 키 추가.
2. OPS: `/api/client/config`에 `turn` 객체 추가( exp/ext HMAC ).
3. 클라이언트: `SipConfig.turn` 수신·전달, 외부 프로필만 적용, `FORCE_RELAY=true` probe.
4. Staging: 라우터 포트 개방 없이 내부에서 relay 강제 검증.
5. 문서·커밋·푸시·색인.

---

## 3. 성공 기준

- SDP에 `typ relay` 후보 존재.
- `REGISTER_OK`, `CALL_OK`, `CONFERENCE_OK`, 2분 유지.
- `ICE failed 0`, `audioLost 0`, 내부 일반 통화 회귀 없음.

---

## 4. 승인 대기

- IPTime 포트포워딩(3478/5349/relay) — 운영 배포 시.
- TURN secret 보관/TTL 정책 최종 확정.
- 인증서 2026-12-31 갱신 책임.
