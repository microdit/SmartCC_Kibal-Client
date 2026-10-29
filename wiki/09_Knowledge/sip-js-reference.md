# SIP.js API 참고 자료

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/web-client]] |

> **참고**: [공식 문서](https://sipjs.com/), [GitHub](https://github.com/sipjs/sip.js)

---

## 1. UserAgent

```typescript
import { UserAgent, URI } from 'sip.js';

const ua = new UserAgent({
  uri: new URI('sip:1001@192.168.11.2'),
  wsServers: ['wss://192.168.11.2:8090/ws'],
  password: 'secret',
  authorizationUser: '1001',
  displayName: 'User1',
});

// 등록
await ua.register();     // REGISTER 전송
await ua.unregister();   // Un REGISTER 전송
```

## 2. 세션 관리 (Session)

```typescript
// 발신 (Caller)
const session = ua.invite('sip:1002@192.168.11.2', {
  session_timers.refresher: 'uac',
  session_timers.refresh_method: 'invitee',
});

// 수신 (Callee) — invite 이벤트 핸들러
ua.delegate = {
  onInviteRequest: (request) => {
    const session = ua.invisibleServer?.acceptRequest(request);
    session?.accept();
  },
  onInvite: (session) => {
    session.accept();
  },
};

// 종료
session.terminate();
```

## 3. 미디어 (WebRTC)

```typescript
// 로컬 미디어 스트림
const localStream = await navigator.mediaDevices.getUserMedia({
  audio: true,
  video: true,
});

// PeerConnection 생성
const pc = new RTCPeerConnection({
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
});

// 로컬 스트림 추가
localStream.getTracks().forEach(track => {
  pc.addTrack(track, localStream);
});

// ICE 후보 전송
pc.onicecandidate = (event) => {
  if (event.candidate) {
    // SIP.js를 통해 상대방에게 전송
    session.sessionDescriptionHandler.writeTransportDescription(
      session, event.candidate
    );
  }
};

// 원격 스트림 수신
pc.ontrack = (event) => {
  const remoteStream = event.streams[0];
  // <video> 요소에 할당
};
```

## 4. SDP Offer/Answer

SIP.js는 `SessionDescriptionHandler`를 통해 SDP 교환을 자동 처리합니다.

```typescript
// INVITE 메시지의 SDP offer 파싱
const offer = await session.sessionDescriptionHandler.getRemoteDescription();
await pc.setRemoteDescription(offer);

// Local SDP answer 생성
const answer = await pc.createAnswer();
await pc.setLocalDescription(answer);

// SIP 200 OK로 answer 전송
await session.sessionDescriptionHandler.setLocalDescription(answer);
```

## 5. 이벤트

| 이벤트 | 설명 |
|--------|------|
| `ua.on('transportCreated', ...)` | WebSocket 전송로 생성 |
| `ua.on('register', ...)` | 등록 성공 |
| `ua.on('unregister', ...)` | 등록 해제 |
| `ua.on('invite', ...)` | INVITE 수신 |
| `session.on('accepted', ...)` | 세션 확립 (200 OK) |
| `session.on('terminated', ...)` | 세션 종료 |
| `session.on('reinvite', ...)` | 재초대 (화면 전환 등) |
| `session.on('message', ...)` | SIP MESSAGE 수신 |

## 6. WebSocket 서버 설정 (Asterisk)

```ini
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
cert_file=/etc/asterisk/keys/cert.pem
priv_key=/etc/asterisk/keys/key.pem
```

## 7. 브라우저 호환성

| 브라우저 | WebSocket | WebRTC | SIP.js |
|----------|-----------|--------|--------|
| Chrome 80+ | ✅ | ✅ | ✅ |
| Edge 80+ | ✅ | ✅ | ✅ |
| Safari 16+ | ✅ (WSS) | ✅ | ✅ |
| Firefox 115+ | ✅ | ✅ | ✅ |

## 8. 디버깅

```javascript
// 로그 레벨 설정
const options = {
  log: {
    level: 'debug',  // 오류 추적용 (개발 환경)
  },
};

// 통화 중 SDP 로그
session.on('trackAdded', (evt) => {
  console.log('Remote track:', evt);
});
```