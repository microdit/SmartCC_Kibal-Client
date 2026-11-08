# SIP Client 설계 (SmartCC_Kibal-Client)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **최종 수정** | 2026-11-07 |
| **버전** | v1.1 |
| **상태** | WebSocket/WebRTC 구현·DEV/PRD 검증 완료 |
| **관련** | [[wiki/02_Design/web-client]], [[wiki/02_Design/mobile-client]], [[wiki/05_Decisions/ADR-002]] |

> **별도 리포지토리**: `SmartCC_Kibal-Client` — Server의 `docs/기획/멀티플랫폼-SIP-clients.md` 평가를 기반으로 한 클라이언트 전용 설계서다.

---

## 1. 설계 배경

WebRTC + SIP.js 기반 웹 클라이언트를 주력으로 한다. 네이티브 모바일은 2026-11-07 기준 `FROZEN`이며, Web 클라이언트의 WebSocket/WebRTC를 먼저 완성한다.

### 1.1 아키텍처 결정 (ADR-002)

| 계층 | 기술 | 비고 |
|------|------|------|
| Web UI | React + TypeScript + Vite | 단일 코드베이스 |
| SIP Client (Web) | SIP.js 0.21 | MIT, WebRTC 연동 |
| Media (Web) | Browser WebRTC API | 브라우저 내장 |
| Mobile UI | Flutter | `FROZEN` |
| SIP/Media (Mobile) | flutter_webrtc + flutter_sip | `FROZEN` |
| 상태 관리 | React state | PoC 범위 |
| 스타일링 | CSS | Tailwind 미적용 |

### 1.2 Web 우선 이유

| 항목 | 이유 |
|------|------|
| 브라우저 호환성 | 설치 없이 Windows/macOS/Android/iOS 동일 코드 |
| 개발 난이도 | 브라우저 WebRTC API 사용, native 빌드 불필요 |
| 업데이트 | 웹 배포로 즉시 반영 |
| 라이선스 | SIP.js MIT |

---

## 2. 시그널링 흐름

### 2.1 SIP 등록 (WebSocket)

```text
┌────────────┐            ┌────────────────────┐
│  Web Client │            │  Asterisk 22 LTS   │
└──────┬─────┘            └─────────┬──────────┘
       │ 1. WebSocket connect       │
       │    ws://<host>:8088/ws     │
       ├───────────────────────────→│
       │ 2. REGISTER                │
       │    sip:1101@<host>         │
       ├───────────────────────────→│
       │ 3. 401 Unauthorized        │
       │    WWW-Authenticate        │
       │◄───────────────────────────┤
       │ 4. REGISTER + Authorization│
       │    Digest (MD5 challenge)  │
       ├───────────────────────────→│
       │ 5. 200 OK                  │
       │◄───────────────────────────┤
       │ 6. re-REGISTER             │
       └───────────────────────────→│
```

- WebSocket 경로: `/ws`, 기본 포트 `8088`
- SIP.js가 Digest challenge-response를 처리한다.
- 서버·클라이언트는 **동일한 plaintext 비밀번호**를 사용한다.
- 사전 계산된 MD5 digest를 비밀번호로 저장하지 않는다.

### 2.2 1:1 영상통화

| 단계 | SIP | 미디어 |
|------|-----|--------|
| 1 | `INVITE` (SDP offer) | - |
| 2 | `100 Trying` / `180 Ringing` | - |
| 3 | `200 OK` (SDP answer) | - |
| 4 | `ACK` | - |
| 5 | - | DTLS-SRTP, Opus/H.264/VP8 |
| 6 | `BYE` | - |

### 2.3 다자간 회의 (ConfBridge SFU)

| 단계 | 설명 |
|------|------|
| 1 | `6000`으로 `INVITE` |
| 2 | Asterisk `ConfBridge` 참여 |
| 3 | `video_mode=sfu`로 참가자별 video m-line 수신 |
| 4 | SIP.js factory에서 video track 누적, track ID별 `MediaStream` 표시 |

---

## 3. Asterisk 서버 설정 (WebRTC)

### 3.1 WebSocket Transport

```ini
[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0:${SIP_WS_PORT}
local_net=192.168.0.0/16
local_net=10.0.0.0/8
local_net=172.16.0.0/12
```

`http.conf.template`:

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=${SIP_WS_PORT}
sessionlimit=100
```

### 3.2 WebRTC Endpoint

```ini
[webrtc-endpoint](!)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
allow=opus
allow=vp8
allow=h264
webrtc=yes
dtls_auto_generate_cert=yes
ice_support=yes
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_use_received_transport=yes
max_audio_streams=1
max_video_streams=8
```

`1101`~`1104`가 이 template을 상속한다. `1001`~`1004`는 legacy UDP endpoint다.

### 3.3 ConfBridge SFU

```ini
[video_bridge]
type=bridge
video_mode=sfu
```

---

## 4. NAT / STUN / TURN

| 항목 | 현재 | 비고 |
|------|------|------|
| STUN | `stun:stun.l.google.com:19302` 기본 | UI에서 변경 가능 |
| TURN | 미구성 | 대칭 NAT/CGNAT 대비 coturn 검토 |
| SDP | Asterisk ICE/DTLS | LAN 검증 완료 |
| 외부망 | `BLOCKED` | WSS + TURN + 포트포워딩 필요 |

---

## 5. 코덱

| 종류 | 코덱 | 비고 |
|------|------|------|
| 오디오 | Opus 48kHz | WebRTC 우선 |
| 오디오 | PCMU/PCMA | Fallback |
| 비디오 | H.264 | WebRTC |
| 비디오 | VP8 | Fallback |

---

## 6. 보안

| 항목 | 현재 | 목표 |
|------|------|------|
| SIP 인증 | Digest (challenge-response MD5) | 유지 |
| 비밀번호 저장 | env/UI plaintext, `localStorage` 저장 안 함 | 유지 |
| `VITE_SIP_PASSWORD` | 제거 | 재도입 금지 |
| 시그널링 | LAN `ws://` | WSS/TLS |
| 미디어 | DTLS-SRTP | 유지 |
| HTTPS 페이지 | `ws://` 차단 | `wss://`만 허용 |

### 6.1 MD5 오해 방지

- MD5는 SIP Digest의 challenge-response 계산에 쓰이는 해시 알고리즘이다.
- 서버 `pjsip.conf`의 `password=`에는 **plaintext 비밀번호**가 들어간다.
- 클라이언트도 같은 plaintext를 입력한다.
- 32자리 hex 값은 우연히 hash처럼 보일 수 있으므로, 서버·클라이언트 값이 같은지 먼저 확인한다.
- `pjsip.conf.template`에 비밀번호를 hardcode하지 않는다.

---

## 7. 환경 변수 (Web Client)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `VITE_SIP_DOMAIN` | `192.168.11.2` | Asterisk 서버 IP/호스트 |
| `VITE_SIP_WS_PORT` | `8088` | WebSocket 포트 |
| `VITE_SIP_WS_SERVER` | `ws://<domain>:8088/ws` | 전체 WebSocket URL |
| `VITE_SIP_USERNAME` | `1101` | 기본 내선 |
| `VITE_SIP_DISPLAY_NAME` | `Kibal Web` | 표시명 |
| `VITE_SIP_PASSWORD` | **사용 안 함** | 번들 노출 방지 |

스모크 스크립트는 `SIP_DOMAIN`, `SIP_WS_SERVER`, `SIP_USERNAME`, `SIP_PASSWORD`, `SIP_PASSWORD_1101`~`1104`를 사용한다.

---

## 8. 관련 문서

- [[wiki/02_Design/web-client]]
- [[wiki/02_Design/mobile-client]]
- [[wiki/05_Decisions/ADR-002]]
- [[wiki/06_Reports/20261107_웹클라이언트_완성_작업계획서]]
- [[wiki/06_Reports/20261107_웹클라이언트_완성_보고서]]
- [[wiki/09_Knowledge/sip-js-reference]]
