# SmartCC Kibal Client PoC 완성 작업계획서

**작성일**: 2026-11-06  
**버전**: v2.0  
**담당**: 개발팀  
**목표**: Web Client MVP + Mobile Client PoC 완성  
**기간**: 2026-11-06 ~ 2026-11-10 (5일)

---

## 📋 Executive Summary

SmartCC Kibal-Client 프로젝트의 **설계 의도(Web 주력)와 구현 현황(Mobile 완성)의 불일치**를 해소하고, **전체 PoC를 완성**하기 위한 작업계획서입니다.

| 목표 | 현재 상태 | 완료 조건 |
|------|---------|----------|
| **Web Client MVP** | ❌ 미시작 | React + SIP.js 기본 통화 구현 |
| **Mobile Android PoC** | ⚠️ 준비됨 | CT03/CT04 검증 완료 |
| **Mobile iOS PoC** | ❌ 불가능 | flutter_sip iOS 구현 또는 대체 |
| **문서화** | ⚠️ 부분 완성 | 실제 구현 상황 반영 |

---

## 🎯 작업 우선순위

### Phase 1: P2 - Web Client MVP 개발 (우선)

**목표**: 설계 의도대로 Web Client를 주력 클라이언트로 구현

**기간**: 2026-11-06 ~ 2026-11-08 (3일)

**근거**:
- 설계 문서의 본래 의도 (Web 주력)
- 빠른 배포 및 업데이트 가능
- CT01/CT02 검증 필요

---

### Phase 2: P0 - Mobile Android PoC 검증 (후속)

**목표**: 완성된 Mobile Client로 CT03/CT04 검증

**기간**: 2026-11-08 ~ 2026-11-09 (2일)

**근거**:
- 이미 구현 완료됨
- Android 테스트 환경 준비 필요
- iOS는 flutter_sip 미구현으로 불가능

---

## 📅 상세 작업 계획

---

## Phase 1: Web Client MVP 개발 (P2 → P1)

**기간**: 2026-11-06 ~ 2026-11-08 (3일)

### Day 1: 2026-11-06 (프로젝트 초기화)

#### 1.1 환경 설정 (2시간)

**목표**: React + TypeScript + Vite 프로젝트 생성

**작업 내용**:
```bash
# 1. Web 프로젝트 생성
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client
npm create vite@latest web -- --template react-ts

# 2. 의존성 설치
cd web
npm install

# 3. SIP.js 및 WebRTC 라이브러리 설치
npm install sip.js
npm install @types/sip.js --save-dev

# 4. 상태 관리 및 스타일링
npm install zustand
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

**결과물**:
- ✅ `web/` 디렉토리 구조 생성
- ✅ 패키지 의존성 설치
- ✅ Tailwind CSS 설정

---

#### 1.2 프로젝트 구조 생성 (1시간)

**목표**: 설계 문서 기반 디렉토리 구조 구축

**디렉토리 구조**:
```
web/
├── src/
│   ├── main.tsx                    ← 엔트리 포인트
│   ├── App.tsx                     ← 메인 앱
│   ├── components/
│   │   ├── Login.tsx               ← SIP 로그인
│   │   ├── Dialer.tsx              ← 다이얼러
│   │   ├── CallView.tsx            ← 1:1 통화 화면
│   │   └── VideoPlayer.tsx         ← 비디오 플레이어
│   ├── lib/
│   │   ├── sipClient.ts            ← SIP.js 클라이언트
│   │   ├── webrtcManager.ts        ← WebRTC 관리
│   │   └── mediaDevices.ts         ← 카메라/마이크
│   ├── stores/
│   │   ├── sipStore.ts             ← SIP 상태 (Zustand)
│   │   └── callStore.ts            ← 통화 상태
│   ├── types/
│   │   └── sip.d.ts                ← SIP 타입 정의
│   └── utils/
│       └── constants.ts            ← 서버 설정
├── public/
├── index.html
├── vite.config.ts
├── tailwind.config.js
└── package.json
```

**결과물**:
- ✅ 디렉토리 구조 완성
- ✅ 빈 파일 생성

---

### Day 2: 2026-11-07 (SIP + WebRTC 구현)

#### 2.1 SIP Client 구현 (3시간)

**목표**: SIP.js를 이용한 등록 및 발신/수신

**파일**: `src/lib/sipClient.ts`

**주요 기능**:
```typescript
import { UserAgent, Registerer, Inviter, Invitation } from 'sip.js';

class SipClient {
  private userAgent: UserAgent;
  private registerer: Registerer;
  
  async register(config: {
    username: string;
    password: string;
    server: string;
    port: number;
  }) {
    // SIP 등록
  }
  
  async makeCall(target: string) {
    // 발신
  }
  
  onIncomingCall(callback: (invitation: Invitation) => void) {
    // 수신
  }
}
```

**테스트 대상**:
- ✅ SIP REGISTER 성공
- ✅ SIP INVITE 발신
- ✅ SIP 수신 핸들링

---

#### 2.2 WebRTC Manager 구현 (3시간)

**목표**: 브라우저 WebRTC API로 미디어 스트림 관리

**파일**: `src/lib/webrtcManager.ts`

**주요 기능**:
```typescript
class WebRTCManager {
  private peerConnection: RTCPeerConnection;
  private localStream: MediaStream;
  private remoteStream: MediaStream;
  
  async getLocalStream() {
    this.localStream = await navigator.mediaDevices.getUserMedia({
      video: { width: 1280, height: 720 },
      audio: true,
    });
    return this.localStream;
  }
  
  async createOffer() {
    // SDP Offer 생성
  }
  
  async handleAnswer(sdp: string) {
    // SDP Answer 처리
  }
  
  onTrack(callback: (track: MediaStreamTrack) => void) {
    // 원격 미디어 수신
  }
}
```

**테스트 대상**:
- ✅ 로컬 카메라/마이크 접근
- ✅ SDP Offer/Answer 생성
- ✅ 원격 스트림 수신

---

### Day 3: 2026-11-08 (UI 구현 및 통합 테스트)

#### 3.1 UI 컴포넌트 구현 (4시간)

**목표**: React 컴포넌트로 사용자 인터페이스 구축

**컴포넌트 목록**:

1. **Login.tsx** (로그인 화면)
   - SIP 계정 입력 (내선번호, 비밀번호, 서버)
   - 등록 버튼
   - 등록 상태 표시

2. **Dialer.tsx** (다이얼러)
   - 전화번호 입력
   - 숫자 키패드
   - 통화 버튼

3. **CallView.tsx** (통화 화면)
   - 로컬 비디오 (작은 화면)
   - 원격 비디오 (큰 화면)
   - 종료/음소거/카메라 끄기 버튼

4. **VideoPlayer.tsx** (비디오 플레이어)
   - `<video>` 태그 래퍼
   - MediaStream 바인딩

**스타일링**: Tailwind CSS

**결과물**:
- ✅ 로그인 화면 완성
- ✅ 다이얼러 완성
- ✅ 통화 화면 완성

---

#### 3.2 통합 테스트 (2시간)

**목표**: Asterisk 서버와 실제 연동 테스트

**테스트 시나리오**:

1. **CT01: Web SIP 등록**
   - 웹 브라우저에서 SIP 등록
   - 서버: `ws://192.168.11.2:8089`
   - 계정: `1001` / `secret`
   - 예상 결과: 등록 성공

2. **CT02: Web 1:1 영상통화**
   - 발신: `1001` → `1002`
   - 수신자 응답
   - 양방향 영상/음성 확인
   - 예상 결과: 통화 성공

**검증 도구**:
- Chrome DevTools (WebRTC Internals)
- Asterisk CLI (`asterisk -rvvv`)

**결과물**:
- ✅ CT01 검증 완료
- ✅ CT02 검증 완료
- ✅ Web Client MVP 완성

---

## Phase 2: Mobile Android PoC 검증 (P0)

**기간**: 2026-11-08 ~ 2026-11-09 (2일)

### Day 4: 2026-11-08 (Android 환경 설정)

#### 4.1 Android SDK 설치 (1시간)

**목표**: Android 개발 환경 구축

**작업 내용**:
```bash
# 1. Android SDK cmdline-tools 다운로드
cd /usr/local/Caskroom/android-platform-tools
wget https://dl.google.com/android/repository/commandlinetools-mac-latest.zip
unzip commandlinetools-mac-latest.zip

# 2. ANDROID_HOME 설정
echo 'export ANDROID_HOME=/usr/local/Caskroom/android-platform-tools' >> ~/.zshrc
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' >> ~/.zshrc
source ~/.zshrc

# 3. Flutter doctor 재확인
flutter doctor -v
```

**결과물**:
- ✅ Android SDK 설치
- ✅ ANDROID_HOME 설정
- ✅ Flutter doctor 통과

---

#### 4.2 Android 에뮬레이터 생성 (1시간)

**목표**: Android 가상 기기 생성 및 실행

**작업 내용**:
```bash
# 1. 에뮬레이터 이미지 다운로드
sdkmanager "system-images;android-33;google_apis;x86_64"

# 2. AVD (Android Virtual Device) 생성
avdmanager create avd -n "Pixel_7" -k "system-images;android-33;google_apis;x86_64"

# 3. 에뮬레이터 실행
emulator -avd Pixel_7

# 4. Flutter 기기 확인
flutter devices
```

**결과물**:
- ✅ Android 에뮬레이터 실행 중
- ✅ Flutter가 기기 인식

---

#### 4.3 Flutter 앱 빌드 및 실행 (2시간)

**목표**: Mobile Client를 Android 에뮬레이터에서 실행

**작업 내용**:
```bash
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/mobile

# 1. 의존성 설치
flutter pub get

# 2. Android 빌드 및 실행
flutter run
```

**예상 결과**:
- ✅ 앱이 에뮬레이터에서 실행됨
- ✅ 로그인 화면 표시됨
- ✅ flutter_sip 플러그인 정상 작동

---

### Day 5: 2026-11-09 (CT03/CT04 검증)

#### 5.1 CT03: Mobile SIP 등록 (1시간)

**목표**: Android 앱에서 SIP 등록 성공

**테스트 시나리오**:
1. 에뮬레이터에서 앱 실행
2. SIP 계정 입력
   - 내선번호: `1001`
   - 비밀번호: `secret`
   - 서버: `192.168.11.2`
   - 포트: `5060`
   - 전송프로토콜: UDP
3. "SIP 등록" 버튼 클릭
4. 상태 확인: **등록됨**

**검증 방법**:
```bash
# Asterisk CLI에서 확인
asterisk -rvvv
> pjsip show endpoints
```

**예상 결과**:
- ✅ SIP REGISTER 성공
- ✅ Asterisk에서 endpoint 활성화 확인
- ✅ **CT03 통과**

---

#### 5.2 CT04: Mobile 1:1 영상통화 (2시간)

**목표**: Android 앱에서 1:1 영상통화 성공

**테스트 시나리오**:
1. **발신자**: Android 앱 (`1001`)
   - "다이얼러 열기" 버튼 클릭
   - 수신자 번호 입력: `1002`
   - "통화" 버튼 클릭
   
2. **수신자**: Web Client 또는 다른 SIP 클라이언트 (`1002`)
   - 수신 알림 확인
   - "수락" 버튼 클릭

3. **통화 확인**:
   - 양방향 영상 확인
   - 양방향 음성 확인
   - 카메라 전환 테스트
   - 음소거 테스트

**검증 방법**:
```bash
# Asterisk CLI에서 통화 상태 확인
asterisk -rvvv
> pjsip show channels
```

**예상 결과**:
- ✅ SIP INVITE 성공
- ✅ WebRTC 협상 성공
- ✅ 양방향 미디어 스트림 확인
- ✅ **CT04 통과**

---

## 📊 작업 산출물

### 1. 코드베이스

| 항목 | 경로 | 상태 |
|------|------|------|
| **Web Client** | `web/` | 🔜 신규 생성 |
| **Mobile Client** | `mobile/` | ✅ 기존 완성 |

### 2. 문서

| 문서 | 경로 | 상태 |
|------|------|------|
| **작업계획서** | `wiki/06_Reports/20261106_작업계획서_Web_Mobile_PoC.md` | ✅ 본 문서 |
| **iOS 분석 보고서** | `wiki/06_Reports/20261106_iOS_flutter_sip_분석보고서.md` | ✅ 완료 |
| **Flutter vs 설계 분석** | `wiki/06_Reports/20261106_Flutter_vs_WebRTC설계_분석보고서.md` | ✅ 완료 |

### 3. 테스트 결과

| 테스트 | 플랫폼 | 상태 |
|--------|--------|------|
| **CT01** | Web | 🔜 예정 |
| **CT02** | Web | 🔜 예정 |
| **CT03** | Mobile Android | 🔜 예정 |
| **CT04** | Mobile Android | 🔜 예정 |
| **CT03** | Mobile iOS | ❌ 불가능 |
| **CT04** | Mobile iOS | ❌ 불가능 |

---

## 🎯 성공 기준

### Phase 1 (Web Client MVP)

| 항목 | 성공 기준 |
|------|----------|
| **환경 설정** | ✅ Vite + React + TypeScript 프로젝트 생성 |
| **SIP 등록** | ✅ SIP.js로 Asterisk 등록 성공 |
| **통화 발신** | ✅ SIP INVITE 전송 및 WebRTC 협상 |
| **통화 수신** | ✅ 수신 전화 처리 및 응답 |
| **미디어 스트림** | ✅ 로컬/원격 비디오 렌더링 |
| **CT01/CT02** | ✅ 검증 완료 |

### Phase 2 (Mobile Android PoC)

| 항목 | 성공 기준 |
|------|----------|
| **환경 설정** | ✅ Android SDK + 에뮬레이터 준비 |
| **앱 빌드** | ✅ Flutter 앱이 에뮬레이터에서 실행됨 |
| **SIP 등록** | ✅ flutter_sip로 Asterisk 등록 성공 |
| **1:1 통화** | ✅ flutter_webrtc로 영상통화 성공 |
| **CT03/CT04** | ✅ 검증 완료 |

---

## ⚠️ 리스크 및 대응 방안

### 리스크 1: Web Client 개발 지연

**원인**:
- SIP.js 학습 곡선
- WebRTC API 복잡도
- 브라우저 호환성 문제

**대응**:
- SIP.js 공식 예제 참고: https://sipjs.com/guides/
- WebRTC 샘플 코드 활용: https://webrtc.github.io/samples/
- Chrome/Firefox 브라우저 우선 개발 (Safari는 추후)

**참고**: 기존 Web Client 구현 & 검증 완료 (2026-11-01)
- `/web/src/sip/SipClient.ts` 참고
- `/web/src/App.tsx`에서 1:1 통화 검증됨

---

### 리스크 2: Android 환경 설정 실패

**원인**:
- Android SDK 설치 오류
- Java JDK 버전 불일치
- 에뮬레이터 성능 문제

**대응**:
- Flutter doctor 가이드 따르기
- Java 17 사용 (이미 설치됨 ✅)
- 물리적 Android 기기 사용 고려

---

### 리스크 3: 네트워크/브라우저 호환성 문제

**원인**:
- 브라우저 WebRTC 미지원 (Safari 등)
- NAT/방화벽 차단
- CORS 정책 위반

**대응**:
- Chrome/Firefox 우선 개발
- Asterisk WebSocket 설정: `ws://192.168.11.2:8088/ws` (포트 8088)
  * 이미 검증됨 (2026-11-01 완료)
- STUN/TURN 서버 활용 (Coturn)

**상태**: ✅ Asterisk WebSocket/WebRTC 완벽 지원 확인
- 기존 Web Client에서 1:1 통화 & 3자 회의 검증 완료
- 양방향 오디오/영상, ICE connected, RTP 모두 정상

---

## 📅 일정 요약

| 날짜 | 단계 | 작업 | 소요 시간 |
|------|------|------|----------|
| **2026-11-06** | Phase 1 Day 1 | Web 프로젝트 초기화 | 3시간 |
| **2026-11-07** | Phase 1 Day 2 | SIP + WebRTC 구현 | 6시간 |
| **2026-11-08** | Phase 1 Day 3 | UI 구현 & CT01/CT02 | 6시간 |
| **2026-11-08** | Phase 2 Day 1 | Android 환경 설정 | 4시간 |
| **2026-11-09** | Phase 2 Day 2 | CT03/CT04 검증 | 3시간 |

**총 작업 시간**: 22시간  
**작업 기간**: 4일 (2026-11-06 ~ 2026-11-09)

---

## 🚀 다음 단계 (Phase 3)

### iOS 지원 추가 (2026-11-15 이후)

**목표**: iOS에서 CT03/CT04 검증

**옵션**:

1. **flutter_sip iOS 구현**
   - Swift로 PJSIP 래퍼 개발
   - 시간: 1~2주

2. **대체 플러그인 사용**
   - `sip_ua` (Dart 순수 구현, iOS 지원)
   - `linphone_sdk` (무겁지만 완전 지원)
   - 시간: 3~5일

3. **Native iOS Client**
   - Swift + PJSIP 직접 구현
   - 시간: 2~3주

**권장**: 옵션 2 (`sip_ua` 플러그인)

---

## ✅ 작업 체크리스트

### Phase 1: Web Client MVP

- [ ] Vite + React + TypeScript 프로젝트 생성
- [ ] SIP.js 설치 및 설정
- [ ] WebRTC Manager 구현
- [ ] Login 컴포넌트 구현
- [ ] Dialer 컴포넌트 구현
- [ ] CallView 컴포넌트 구현
- [ ] CT01 검증 (Web SIP 등록)
- [ ] CT02 검증 (Web 1:1 통화)

### Phase 2: Mobile Android PoC

- [ ] Java JDK 17 설치 (✅ 완료)
- [ ] Android SDK cmdline-tools 설치
- [ ] ANDROID_HOME 환경변수 설정
- [ ] Android 에뮬레이터 생성
- [ ] Flutter pub get
- [ ] Flutter 앱 빌드 및 실행
- [ ] CT03 검증 (Mobile SIP 등록)
- [ ] CT04 검증 (Mobile 1:1 통화)

### 문서화

- [x] iOS flutter_sip 분석 보고서 작성 (✅ 완료)
- [x] Flutter vs 설계 분석 보고서 작성 (✅ 완료)
- [x] 작업계획서 작성 (✅ 본 문서)
- [ ] CT01/CT02 검증 보고서 작성
- [ ] CT03/CT04 검증 보고서 작성
- [ ] 최종 완료 보고서 작성

---

## 📞 연락 및 지원

| 항목 | 내용 |
|------|------|
| **문서 경로** | `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client/wiki/06_Reports/` |
| **Git 리포지토리** | `git@github.com:microdit/SmartCC_Kibal-Client.git` |
| **Asterisk 서버** | `192.168.11.2:5060` (SIP), `:8089` (WebSocket) |

---

**작성자**: Claude Code  
**검토자**: -  
**승인자**: -  
**상태**: 작성 완료 ✅

