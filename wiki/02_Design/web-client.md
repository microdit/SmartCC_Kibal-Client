# Web Client 설계 (React + SIP.js + WebRTC)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 계획 중 |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/mobile-client]], [[wiki/05/Decisions/ADR-002]] |

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
- `wss://192.168.11.2:8090/ws` WebSocket 연결
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