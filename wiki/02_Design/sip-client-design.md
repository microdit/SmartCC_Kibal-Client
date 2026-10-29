# SIP Client 설계 (SmartCC_Kibal-Client)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 작업중 |
| **관련** | [[wiki/02_Design/architecture]], [[wiki/02_Design/sip-client]], [[wiki/02_Design/web-client]], [[wiki/02_Design/mobile-client]], [[docs/기획/멀티플랫품-SIP-clients]] |

> **별도 리포지토리**: `SmartCC_Kibal-Client` — Server의 `docs/기획/멀티플랫폼-SIP-clients.md` 평가를 기반으로 한 클라이언트 전용 설계서입니다.

---

## 1. 설계 배경

`멀티플랫폼-SIP-clients.md` 평가에서 **WebRTC + SIP.js** 기반 웹 클라이언트를 주력으로 삼는 것이 초기 개발 속도, 플�랫폼 호환성, 배포 및 유지보수 측면에서 유리하다고 결정했습니다.

### 1.1 아키텍처 결정 (ADR-002)

| 계층 | 기술 | 비고 |
|------|------|------|
| Web UI | React + TypeScript + Vite | 단일 코드베이스 → 다중 플랫폼 |
| SIP Client (Web) | SIP.js | MIT License, WebRTC와 연동 |
| Media (Web) | Browser WebRTC API | 브라우저 내장 |
| Mobile UI | Flutter | iOS / Android 네이티브 빌드 |
| SIP/Media (Mobile) | flutter_webrtc + flutter_sip | WebRTC 기반 |
| 상태 관리 | Zustand (Web) / Provider (Mobile) | 경량 |
| 스타일링 | Tailwind CSS v3 | 컴포넌트 재사용 |

### 1.2 왜 SIP.js + WebRTC 인가

| 항목 | 이유 |
|------|------|
| **브라우저 호환성** | 별도 앱 설치 없이 URL 접속 → Windows/macOS/Android/iOS 모두 동일 코드 |
| **개발 난이도** | native 빌드 없이 브라우저 WebRTC API 사용 → PJSUA2 복잡성 회피 |
| **업데이트** | 웹 서버 배포 → 즉시 반영, 앱스토어 의존성 없음 |
| **라이선스** | SIP.js (MIT) → 독점 상용 제품 개발 가능 (Asterisk GPL 제외) |

---

## 2. 시그널링 흐름 (WebRTC + SIP.js)

### 2.1 SIP 등록 (Register)

```
┌────────────┐            ┌────────────────────┐
│  Web Client │            │  Asterisk 22 LTS   │
└──────┬─────┘            └─────────┬──────────┘
       │ 1. REGISTER (WSS)          │
       │  sip:1001@192.168.11.2     │
       ├───────────────────────────→│
       │                            │
       │ 2. 401 Unauthorized         │
       │    WWW-Authenticate       │
       │◄───────────────────────────┤
       │                            │
       │ 3. REGISTER (re-auth)      │
       │    Authorization: MD5      │
       ├───────────────────────────→│
       │                            │
       │ 4. 200 OK                  │
       │    Contact: <sip:...>      │
       │◄───────────────────────────┤
       │                            │
       │ 5. re-REGISTER (3600s)     │
       │    (120초 주기)             │
       └───────────────────────────→ (loop)
```

### 2.2 1:1 영상통화 (INVITE → 200 OK → ACK → RTP)

| 단계 | SIP 메시지 | 미디어 | 설명 |
|------|-----------|--------|------|
| 1 | `INVITE` (SDP offer) | - |Caller → callee 1002, H.264 오퍼 |
| 2 | `100 Trying` / `180 Ringing` | - | 서버 전달 |
| 3 | `200 OK` (SDP answer) | - | Callee 수신, H.264 앤서 |
| 4 | `ACK` | - | 세션 확정 |
| 5 | - | RTP/RTCP | H.264 video + Opus audio |
| 6 | `BYE` | - | 통화 종료 |

### 2.3 다자간 회의 (ConfBridge SFU)

| 단계 | 설명 |
|------|------|
| 1 | 회의실 번호 6000으로 `INVITE` (SIP) |
| 2 | Asterisk `ConfBridge` 참여 |
| 3 | SFU 모델: 각 클라이언트가 서로 다른 스트림을 수신 |
| 4 | 다중 `<video>` 요소로 참가자 영상을 격자 레이아웃 |

---

## 3. Asterisk 서버 설정 (WebRTC 전용)

### 3.1 PJSIP WebSocket Transport

```ini
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
cert_file=/etc/asterisk/keys/cert.pem
priv_key=/etc/asterisk/keys/key.pem
```

### 3.2 WebRTC Endpoint 템플릿

```ini
[webrtc-endpoint]
type=endpoint
context=internal
disallow=all
allow=opus,ulaw,vp8,h264
webrtc=yes
direct_media=no
max_audio_streams=1
max_video_streams=8
```

> `webrtc=yes`는 ICE, DTLS-SRTP, RTCP 멀티플렉싱을 활성화합니다.

### 3.3 ConfBridge SFU 설정

```ini
[video_bridge]
type=bridge
video_mode=sfu
```

---

## 4. NAT / STUN / TURN

| 항목 | 설정 |
|------|------|
| STUN 서버 | `stun.l.google.com:19302` (브라우저 자동) |
| TURN (필요 시) | Asterisk Coturn 연동 (`turnuser/turnpass`) |
| SDP 주소 | `c=IN IP4 <공인IP>` (Asterisk `sip.conf`) |

---

## 5. 코덱

| 종류 | 코덱 | 비고 |
|------|------|------|
| 오디오 | Opus 48kHz | 우선순위 1 |
| 오디오 | PCMU/PCMA | Fallback |
| 비디오 | H.264 (Baseline/Main) | `profile-level-id=42e01f` |
| 비디오 | VP8 | Fallback (WebRTC) |

### SDP 예시 (Audio + Video)

```
v=0
o=- 123456 1 IN IP4 0.0.0.0
s=-
c=IN IP4 0.0.0.0
t=0 0
m=audio 10000 RTP/AVP 111
a=rtpmap:111 opus/48000/2
m=video 10002 RTP/AVP 96
a=rtpmap:96 H264/90000
a=fmtp:96 profile-level-id=42e01f;packetization-mode=1
```

---

## 6. 보안

| 항목 | 설정 |
|------|------|
| SIP 인증 | Digest (MD5) |
| 시그널링 | SIPS / SIP over TLS (5061) |
| 미디어 | SRTP (DTLS-SRTP) |
| WebSocket | WSS (443) |

### 환경 변수 (Web Client)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `SIP_DOMAIN` | `192.168.11.2` | Asterisk 서버 IP |
| `SIP_PORT` | `5060` | SIP UDP 포트 |
| `WS_PORT` | `8089` | WebSocket 포트 |
| `WS_TLS_PORT` | `8090` | WSS 포트 |
| `RTP_MIN` | `10000` | RTP 포트 시작 |
| `RTP_MAX` | `10010` | RTP 포트 종료 |

---

## 7. 관련 문서

- [[wiki/02_Design/sip-client]] — SIP Client 기본 설계 (별도 리포지토리 참조 버전)
- [[wiki/02_Design/web-client]] — Web Client 상세 설계 (React + SIP.js)
- [[wiki/02_Design/mobile-client]] — Mobile Client 설계 (Flutter)
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정
- [[wiki/09_Knowledge/sip-js-reference]] — SIP.js API 참고 자료