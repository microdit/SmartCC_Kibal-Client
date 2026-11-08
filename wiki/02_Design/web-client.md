# Web Client 설계 (React + SIP.js + WebRTC)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **최종 수정** | 2026-11-07 |
| **버전** | v1.2 |
| **상태** | WebSocket/WebRTC 완성 · DEV/PRD 검증 완료 |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/05_Decisions/ADR-002]], [[wiki/06_Reports/20261107_웹클라이언트_완성_보고서]] |

---

## 0. 현재 구현 현황 (2026-11-07)

`web/`는 SIP 등록·1:1 영상통화·6000 회의실 SFU를 검증하는 **실사용 가능한 Web 클라이언트**다.

| 항목 | 파일 | 상태 |
|------|------|------|
| React 엔트리 | `web/src/main.tsx` | 완료 |
| 테스트 UI | `web/src/App.tsx` | 완료 |
| 스타일 | `web/src/styles.css` | 완료 |
| SIP.js 래퍼 | `web/src/sip/SipClient.ts` | 완료 |
| 설정 검증 | `web/src/config.ts` | 완료 |
| Node 등록 스모크 | `web/scripts/register-smoke.mjs` | 완료 |
| 브라우저 스모크 | `web/scripts/browser-smoke.mjs` | 완료 |
| Tailwind/Zustand/React Router | - | 미적용 (의도적 최소 구성) |

검증 결과(2026-11-07):

| ID | DEV | PRD |
|----|-----|-----|
| CT01 SIP 등록·해제 | PASS | PASS |
| CT02 1:1 영상 | PASS, remote video 1 | PASS, remote video 1 |
| CT05 3자 SFU | PASS, remote video 2 | PASS, remote video 2 |
| 마이크·카메라 toggle | PASS | PASS |

증거: Server `docs/_작업이력/evidence/20261107-web-completion/`

---

## 1. 구조

```text
web/
├── src/
│   ├── main.tsx
│   ├── App.tsx                 ← 등록·다이얼·수신·영상 타일·로그 UI
│   ├── config.ts               ← env 기본값·설정 검증·정규화
│   ├── sip/
│   │   └── SipClient.ts        ← UserAgent/Registerer/Session/미디어 제어
│   └── styles.css
├── scripts/
│   ├── register-smoke.mjs
│   └── browser-smoke.mjs
├── .env.example
├── package.json
└── vite.config.ts
```

향후 화면이 늘어나면 `features/`, `hooks/`, `store/`로 분리한다. 현재 PoC 범위에서는 파일 수를 늘리지 않는다.

---

## 2. 설정 모델

```ts
export interface SipConfig {
  username: string;
  password: string;
  domain: string;
  wsServer: string;
  displayName: string;
  iceServers: string[];
}
```

### 2.1 원칙

| 항목 | 정책 |
|------|------|
| 기본 도메인 | `VITE_SIP_DOMAIN` (기본 `192.168.11.2`) |
| 기본 WebSocket | `VITE_SIP_WS_SERVER` (기본 `ws://<domain>:8088/ws`) |
| 내선/표시명 | `VITE_SIP_USERNAME`, `VITE_SIP_DISPLAY_NAME` |
| **비밀번호** | **env에 넣지 않는다. UI 입력만 사용한다.** |
| 저장 | `localStorage`에 password를 제외한 설정만 저장 |
| STUN/TURN | UI에서 쉼표 구분 입력, 기본 `stun:stun.l.google.com:19302` |

`VITE_*` 값은 브라우저 번들에 포함되므로 비밀번호·토큰을 넣으면 안 된다.

### 2.2 검증 규칙

`validateSipConfig()`가 등록 전에 확인한다.

- 내선: 영문·숫자·`._-`, 32자 이내
- 도메인: IP 또는 호스트명, scheme/path 금지
- WebSocket: `ws://` 또는 `wss://`만 허용
- 경로가 `/`이면 `/ws`로 정규화
- HTTPS 페이지에서 `ws://` 사용 시 오류 (mixed content)
- STUN/TURN scheme 오류는 경고

---

## 3. SIP 등록 lifecycle

`KibalSipClient.connect()` 흐름:

1. `UserAgent.makeURI("sip:<user>@<domain>")`
2. `UserAgent` 생성 — `transportOptions.server = wsServer`
3. `ua.start()` — WebSocket 연결, **15초 타임아웃**
4. `Registerer.register()` — **15초 타임아웃**
5. `Registered` 상태 확인
6. 실패 시 transport 정리 후 오류 반환

`disconnect()`는 최대 5초 안에 `unregister()` 후 `ua.stop()`을 수행한다. 예기치 않은 WebSocket 종료는 `onRegistration("disconnected")`로 UI에 표시하고, UI의 **재연결** 버튼으로 `disconnect → connect`를 수행한다.

### 3.1 SIP 인증

- SIP Digest는 인증 시점에 challenge-response로 MD5를 계산한다.
- 서버 `SIP_PASSWORD_*`와 클라이언트 입력 비밀번호는 **동일한 plaintext**여야 한다.
- 사전 계산된 MD5 digest를 비밀번호로 넣지 않는다.
- `pjsip.conf.template`의 `${SIP_PASSWORD_*}` placeholder는 유지한다.
- 2026-11-06 DEV 장애는 stale 컨테이너의 32자리 hex 런타임 값과 `.env` 불일치가 원인이었다.

---

## 4. 1:1 통화와 미디어

- `Inviter`/`Invitation` + `SessionDescriptionHandler`
- `audio: true`, `video: 1280x720 ideal`
- 수신 중 다른 INVITE가 오면 busy로 거절
- 통화 중 마이크·카메라 `MediaStreamTrack.enabled` toggle
- `attachMedia()`가 원격 track을 track ID별 `MediaStream`으로 재사용
- 세션 종료·PC closed/failed 시 `attachMedia()` cleanup이 interval/listener를 제거하고 track 참조를 해제

### 4.1 SFU 다중 영상

SIP.js 기본 원격 track 처리는 오디오/비디오 각 1개만 유지한다. ConfBridge `video_mode=sfu`의 다중 video m-line을 표시하려면:

1. `sessionDescriptionHandlerFactory`에서 `setRemoteTrack()`의 video 분기를 누적 방식으로 교체
2. `attachMedia()`에서 track ID별 `MediaStream` 재사용
3. 매 polling마다 새 `MediaStream`을 만들지 않는다

이 보완으로 3자 회의에서 원격 영상 2개가 동시에 표시된다.

---

## 5. 화면

### 5.1 SIP 연결

- 서버 도메인, WebSocket URL, 내선, 비밀번호, STUN/TURN
- 등록/등록 해제/재연결
- 등록 상태 pill, 오류, 설정 경고

### 5.2 통화

- 대상 번호 또는 `6000` 회의실
- 수신 받기/거절
- 통화 종료
- 마이크 끄기/켜기, 카메라 끄기/켜기
- 세션 상태

### 5.3 영상

- 원격 track grid (참가자별 타일)
- 로컬 PiP
- SIP 로그 접기/펼치기

---

## 6. 빌드·검증

```bash
cd web
npm install
npm run typecheck
npm run build

# DEV 등록
SIP_DOMAIN=127.0.0.1 SIP_WS_SERVER=ws://127.0.0.1:8088/ws \
SIP_USERNAME=1101 SIP_PASSWORD=<DEV_1101_PASSWORD> \
npm run smoke:register

# DEV 1:1
SIP_DOMAIN=127.0.0.1 SIP_WS_SERVER=ws://127.0.0.1:8088/ws \
SIP_PASSWORD_1101=<DEV_1101_PASSWORD> SIP_PASSWORD_1102=<DEV_1102_PASSWORD> \
npm run smoke:call

# PRD 3자 회의
SIP_DOMAIN=192.168.11.2 SIP_WS_SERVER=ws://192.168.11.2:8088/ws \
SIP_PASSWORD_1101=<PRD_1101_PASSWORD> SIP_PASSWORD_1102=<PRD_1102_PASSWORD> \
SIP_PASSWORD_1103=<PRD_1103_PASSWORD> npm run smoke:room3
```

브라우저 스모크는 fake media + headless Chrome을 사용하며, 등록·통화·미디어 toggle·원격 track 수를 검사한다.

---

## 7. 남은 과제

| 우선순위 | 항목 | 상태 |
|----------|------|------|
| P1 | WSS/TLS 인증서·HTTPS 배포 | 미구성 |
| P1 | TURN(coturn), 외부망 CT06 | BLOCKED |
| P2 | Playwright UI 회귀·모바일 390px | 미완료 |
| P2 | 다중 참가자 4명 이상 레이아웃 | 미검증 |
| P2 | 통화 기록·장치 선택 UI | 미구현 |

---

## 8. 관련 문서

- [[wiki/02_Design/sip-client-design]]
- [[wiki/02_Design/mobile-client]]
- [[wiki/05_Decisions/ADR-002]]
- [[wiki/06_Reports/20261107_웹클라이언트_완성_작업계획서]]
- [[wiki/06_Reports/20261107_웹클라이언트_완성_보고서]]
- [[wiki/09_Knowledge/sip-js-reference]]
