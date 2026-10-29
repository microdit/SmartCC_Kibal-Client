# 크로스플랫폼 클라이언트 설계 (Cross-Platform Client Design)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 결정됨 |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/web-client]], [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/iOS-client-design]], [[wiki/05/Decisions/ADR-002]] |

---

## 1. 개요

`멀티플랫폼-SIP-clients.md` 평가에서 **WebRTC + SIP.js 기반 Web Client**를 주력으로 삼되, 향후 모바일 백그라운드 전화 수신을 위해 **Flutter native** 또는 **iOS/Android native**로 확장할 수 있는 크로스플랫폼 전략을 수립했습니다.

---

## 2. 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Kibal Client (Unified)                      │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  Web Client   │  │  Mobile       │  │  Native (Future) │  │
│  │  (React)      │  │  (Flutter)    │  │  (Swift/Kotlin) │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │              │
│         └────────┬────────┴────────────────────┘              │
│                  │                                             │
│         ┌────────▼────────┐                                   │
│         │  SIP Layer      │                                   │
│         │  · SIP.js (Web) │                                   │
│         │  · flutter_sip   │                                   │
│         │  (Mobile)       │                                   │
│         │  · PJSIP (Native)│                                   │
│         └────────┬────────┘                                   │
│                  │                                             │
│         ┌────────▼────────┐                                   │
│         │  Media Layer    │                                   │
│         │  · WebRTC (Web) │                                   │
│         │  · flutter_webrtc │                                   │
│         │  (Mobile)       │                                   │
│         │  · AVFoundation   │                                   │
│         │  (iOS Native)     │                                   │
│         └────────┬────────┘                                   │
│                  │                                             │
└──────────────────┼─────────────────────────────────────────────┘
                   │ WebSocket (WSS / SIP/TLS)
┌──────────────────┼─────────────────────────────────────────────┐
│                   │                                             │
│  Asterisk 22 LTS   │  ConfBridge SFU  │  Coturn (STUN/TURN)    │
│                   │                                             │
└───────────────────────────────────────────────────────────────┘
```

---

## 3. 클라이언트 계층

### 3.1 계층 1: Web Client (MVP)

| 항목 | 기술 |
|------|------|
| UI | React + TypeScript + Vite |
| SIP | SIP.js (MIT) |
| Media | Browser WebRTC API |
| 배포 | Nginx + Docker |
| PWA | 지원 (iOS 15+, Android) |

**장점**: 단일 코드베이스, 즉시 배포, 낮은 진입 장벽
**제약**: iOS 백그라운드 제한

### 3.2 계층 2: Flutter Mobile

| 항목 | 기술 |
|------|------|
| UI | Flutter (iOS + Android) |
| SIP | flutter_sip (PJSIP 래퍼) |
| Media | flutter_webrtc |
| 배포 | Google Play / App Store |

**장점**: 네이티브 앱, 푸시 알림, 카메라 제어
**제약**: PJSIP 빌드 복잡성

### 3.3 계층 3: Native (Future)

| 항목 | iOS | Android |
|------|-----|---------|
| 언어 | Swift 5.9+ | Kotlin 2.0+ |
| SIP | PJSIP XCFramework | PJSIP AAR |
| Media | AVFoundation | CameraX / MediaCodec |
| 백그라운드 | VoIP (PushKit) | Foreground Service |

**장점**: 완전한 시스템 통합, 백그라운드 전화 수신
**제약**: 별도 개발/유지보수

---

## 4. 기능 매트릭스

| 기능 | Web | Flutter | Native iOS | Native Android |
|------|-----|---------|-------------|----------------|
| SIP 등록 | ✅ | ✅ | ✅ | ✅ |
| 1:1 영상통화 | ✅ | ✅ | ✅ | ✅ |
| 다자간 회의 | ✅ | ✅ | ✅ | ✅ |
| 백그라운드 수신 | ❌ | ⚠️ (limited) | ✅ (VoIP) | ✅ (FG) |
| 푸시 알림 | ❌ | ✅ | ✅ (APNs) | ✅ (FCM) |
| 카메라 전환 | ✅ | ✅ | ✅ | ✅ |
| 화면 공유 | ✅ | ⚠️ | ✅ | ✅ |
| 앱스토어 배포 | ❌ | ✅ | ✅ | ✅ |
| 즉시 업데이트 | ✅ | ❌ | ❌ | ❌ |

---

## 5. 개발 로드맵

| 단계 | 대상 | 목표 | 완료 조건 |
|------|------|------|----------|
| C1 | Web | 프로젝트 초기화 | Git + Wiki + venv |
| C2 (MVP-1) | Web | 1:1 영상통화 | SIP.js REGISTER + WebRTC |
| C3 (MVP-2) | Flutter | 모바일 1:1 | flutter_sip + flutter_webrtc |
| C4 | Web | Docker 배포 | Nginx 컨테이너 |
| C5 | 통합 | 3자 회의 | SFU + 다중 브라우저 |
| C6 | Native | iOS 배경 수신 | VoIP + PushKit |

---

## 6. 공통 설계 (공유 컴포넌트)

### 6.1 SIP 설정 (공통)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `SIP_DOMAIN` | `192.168.11.2` | Asterisk 서버 IP |
| `SIP_PORT` | `5060` | SIP UDP/TCP 포트 |
| `WS_PORT` | `8089` | WebSocket 포트 |
| `WS_TLS_PORT` | `8090` | WSS 포트 |
| `RTP_MIN` | `10000` | RTP 포트 시작 |
| `RTP_MAX` | `10010` | RTP 포트 종료 |

### 6.2 미디어 설정 (공통)

| 항목 | 값 |
|------|------|
| 오디오 코덱 | Opus 48kHz (우선), PCMU/PCMA (fallback) |
| 비디오 코덱 | H.264 (Baseline/Main, `profile-level-id=42e01f`) |
| 비디오 해상도 | 720p (최대), 360p (fallback) |
| 프레임레이트 | 30fps |
| STUN | `stun.l.google.com:19302` |
| TURN | Asterisk Coturn (`turnuser/turnpass`) |

---

## 7. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/02_Design/web-client]] — Web Client (React + SIP.js)
- [[wiki/02_Design/mobile-client]] — Mobile Client (Flutter)
- [[wiki/02_Design/macOS-client-design]] — Native macOS Client
- [[wiki/02_Design/iOS-client-design]] — Native iOS Client
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정
- [[wiki/05/Decisions/ADR-003]] — iOS Native Client 결정 (Background Reception)