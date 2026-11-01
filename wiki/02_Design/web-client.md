# Web Client 설계 (React + SIP.js + WebRTC)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 구현·LAN 검증 완료 (2026-11-01) |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/mobile-client]], [[wiki/05/Decisions/ADR-002]] |

---

## 0. 구현 현황 (2026-11-01)

현재 `web/`는 설계 문서의 전체 구조가 아니라 SIP 등록·1:1 영상·회의실 참가를 검증하는 최소 테스트 클라이언트로 구현되어 있다.

| 항목 | 파일 | 상태 |
|------|------|------|
| React 엔트리 | `web/src/main.tsx` | 완료 |
| 테스트 UI | `web/src/App.tsx` | 완료 |
| 스타일 | `web/src/styles.css` | 완료 |
| SIP.js 래퍼 | `web/src/sip/SipClient.ts` | 완료 |
| 설정 | `web/src/config.ts` | 완료 |
| Node 등록 스모크 | `web/scripts/register-smoke.mjs` | 완료 |
| 브라우저 스모크 | `web/scripts/browser-smoke.mjs` | 완료 |
| Tailwind/Zustand/React Router | - | 미적용 (테스트 클라이언트 범위) |

검증 결과:

- DEV: WebSocket `ws://127.0.0.1:8088/ws` 등록·해제 성공
- PRD: `ws://192.168.11.2:8088/ws` 등록·해제 성공
- PRD 1:1 (`1101` → `1102`): 양방향 오디오·영상, ICE connected, inbound/outbound RTP 확인
- PRD 회의실 `6000` (`1101`/`1102`/`1103`): 3자 입장, 각 참가자 오디오 믹싱 수신, 원격 영상 320x180/480x270 수신 확인
- 3자 회의에서 원격 video receiver는 2개가 live로 관측되나 UI는 1개 타일만 렌더링하는 경우가 있어 다중 타일 표시는 추가 검증이 필요하다.

### 검증 명령

```bash
cd web
npm run build

# Node SIP 등록 (DEV 예시)
SIP_DOMAIN=127.0.0.1 SIP_WS_SERVER=ws://127.0.0.1:8088/ws SIP_USERNAME=1101 SIP_PASSWORD=<DEV_1101_비밀번호> npm run smoke:register

# 브라우저 1:1 (PRD 예시)
SIP_DOMAIN=192.168.11.2 SIP_WS_SERVER=ws://192.168.11.2:8088/ws SIP_PASSWORD_1101=<PRD_1101_비밀번호> SIP_PASSWORD_1102=<PRD_1102_비밀번호> npm run smoke:call

# 브라우저 3자 회의실
SIP_ROOM=1 SIP_ROOM_THIRD=1 SIP_DOMAIN=192.168.11.2 SIP_WS_SERVER=ws://192.168.11.2:8088/ws SIP_PASSWORD_1101=<PRD_1101_비밀번호> SIP_PASSWORD_1102=<PRD_1102_비밀번호> SIP_PASSWORD_1103=<PRD_1103_비밀번호> node scripts/browser-smoke.mjs
```

---

## 1. 프로젝트 구조

```
web/
├── public/
│   ├── index.html
│   └── favicon.ico
├── src/
│   ├── app/
│   │   ├── App.tsx              ← 라우팅 (React Router v6)
│   │   ├── index.tsx            ← React 엔트리
│   │   └── providers/           ← 컨텍스트 프로바이더
│   │       ├── SipProvider.tsx  ← SIP.js UserAgent 컨텍스트
│   │       └── MediaProvider.tsx ← WebRTC media 컨텍스트
│   ├── components/
│   │   ├── common/              ← 공통 UI (Button, Input, Badge)
│   │   ├── layout/              ← Header, Sidebar, Footer
│   │   └── ui/                  ← Tailwind 스타일 컴포넌트
│   ├── features/
│   │   ├── login/               ← SIP 등록 화면
│   │   ├── dialer/              ← 다이얼러 화면
│   │   ├── call/                ← 1:1 영상통화 화면
│   │   └── conference/          ← 회의실 화면
│   ├── sip/
│   │   ├── SipClient.ts         ← SIP.js UserAgent 래퍼
│   │   ├── SipSession.ts        ← 세션 관리
│   │   ├── MediaManager.ts      ← WebRTC MediaStream 관리
│   │   └── ConferenceManager.ts ← ConfBridge 참여 관리
│   ├── hooks/
│   │   ├── useSip.ts            ← SIP 상태 훅
│   │   ├── useMedia.ts          ← 미디어 스트림 훅
│   │   └── useConference.ts     ← 회의 상태 훅
│   ├── store/
│   │   └── index.ts             ← Zustand 스토어
│   ├── pages/
│   │   ├── LoginPage.tsx
│   │   ├── DialerPage.tsx
│   │   ├── CallPage.tsx
│   │   └── ConferencePage.tsx
│   ├── styles/
│   │   └── index.css            ← Tailwind CSS
│   ├── utils/
│   │   └── constants.ts         ← 상수
│   └── types/
│       └── index.ts             ← TypeScript 타입
├── package.json
├── vite.config.ts
├── tsconfig.json
└── tailwind.config.js
```

---

## 2. 핵심 컴포넌트

### 2.1 SipClient.ts — SIP.js UserAgent 래퍼

```typescript
import { UserAgent } from 'sip.js';

export class KibalSipClient {
  private ua: UserAgent;

  constructor(config: SipConfig) {
    this.ua = new UserAgent({
      uri: new URI(`sip:${config.username}@${config.domain}`),
      wsServers: [config.wsServer],
      password: config.password,
      displayName: config.displayName,
    });
  }

  async register(): Promise<boolean> { ... }
  async unregister(): Promise<void> { ... }
  async makeCall(target: string, options: CallOptions): Promise<SipSession> { ... }
  async answerCall(session: Session): Promise<void> { ... }
  async hangup(session: Session): Promise<void> { ... }
}
```

### 2.2 MediaManager.ts — WebRTC 관리

```typescript
export class MediaManager {
  private localStream: MediaStream | null = null;
  private peerConnections: Map<string, RTCPeerConnection> = new Map();

  async getLocalMedia(constraints: MediaStreamConstraints): Promise<MediaStream> {
    this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
    return this.localStream;
  }

  createPeerConnection(config: RTCConfiguration): RTCPeerConnection { ... }
  closeAll(): void { ... }
}
```

### 2.3 ConferenceManager.ts — ConfBridge 참여

```typescript
export class ConferenceManager {
  private conferenceId: string = '6000';
  private participantStreams: Map<string, MediaStream> = new Map();

  async joinConference(displayName: string): Promise<void> { ... }
  async leaveConference(): Promise<void> { ... }
}
```

---

## 3. 화면 (Pages)

### 3.1 로그인 / SIP 등록 (LoginPage)

- SIP 계정 입력 (내선번호, 비밀번호)
- `ws://192.168.11.2:8088/ws` WebSocket 연결 (내부 LAN, TLS 미적용)
- REGISTER 전송 → 200 OK 확인
- 등록 상태 표시 (등록됨 / 등록 실패)

### 3.2 다이얼러 (DialerPage)

- 숫자 패드 (0-9, *, #)
- 내선번호 입력 (1001~1004)
- 음성/영상 전환 토글
- 최근 통화 기록 (간단히)

### 3.3 통화 화면 (CallPage)

```
┌─────────────────────────────────────────┐
│  [Local Video]          [Remote Video]  │
│  (작은 창)               (메인 화면)      │
├─────────────────────────────────────────┤
│  [음소거] [카메라 전환] [통화 종료]       │
└─────────────────────────────────────────┘
```

- 로컬/원격 영상 겹치기 (picture-in-picture)
- 음소거 토글, 카메라 전환 (front/back)

### 3.4 회의실 (ConferencePage)

```
┌──────────┬──────────┬──────────┐
│  참가자 1 │  참가자 2 │  참가자 3 │
├──────────┼──────────┼──────────┤
│  참가자 4 │           │          │
└──────────┴──────────┴──────────┘
[입장] [퇴장] [음소거] [종료]
```

- 6000번 회의실 접속
- 격자 레이아웃 (최대 4명)
- 참가자 이름/상태 표시

---

## 4. 빌드 및 배포

```bash
cd web/
npm install
npm run dev    # Vite dev server (localhost:5173)
npm run build  # dist/ 디렉토리 생성
```

### Docker (kibal-web)

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --frozen-lockfile
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## 5. 브라우저 호환성

| 브라우저 | SIP.js | WebRTC | 영상통화 | 다자간 |
|----------|--------|--------|----------|--------|
| Chrome | ✅ | ✅ | ✅ | ✅ |
| Edge | ✅ | ✅ | ✅ | ✅ |
| Safari 16+ | ✅ | ✅ | ✅ | ✅ |
| Firefox | ✅ | ✅ | ✅ | ✅ |
| Mobile Safari | ✅ | ✅ | ✅ | ✅ (iOS 15+) |

> **참고**: iOS Safari는 백그라운드 전환 시 WebRTC 세션이 제한될 수 있습니다. 상시 전화 수신을 위해서는 네이티브 앱이 필요합니다 (ADR-003 참조).

---

## 6. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/02_Design/mobile-client]] — Mobile Client (Flutter)
- [[wiki/04_Prompts/work-commands]] — 개발 명령어 (Docker, Vite)
- [[wiki/03_Guides/development-guide]] — 클라이언트 개발 가이드