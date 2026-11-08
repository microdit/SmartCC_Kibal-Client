# macOS Client UI 설계 (Native macOS SIP Client)

| 항목 | 값 |
|------|-----|
| **작성일** | 2026-11-08 |
| **버전** | v1.0 |
| **상태** | 설계 완료 (macOS 빌드 검증 준비) |
| **관련** | [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/mobile-client]], [[wiki/02_Design/sip-client-design]] |

---

## 1. 화면 구성

macOS 네이티브 앱의 전체 화면 레이아웃은 다음과 같다.

```text
┌──────────────────────────────────────────────────────────────┐
│  ■☐ □  Kibal  🔔  🔔  ⋯  [종료]                            │
│  ┌──────────┐ ┌────────────────────────────────────────────┐ │
│  │ 내선/    │ │                    │                       │ │
│  │ 상태바   │ │                    │                       │ │
│  │ (status) │ │                    │                       │ │
│  │ ⏺      │ │                    │                       │ │
│  │ 📡      │ │                    │                       │ │
│  │ 📞      │ │                    │                       │ │
│  │ ⚙️      │ │                    │                       │ │
│  └──────────┘ └────────────────────────────────────────────┘ │
│                                                              │
│  (로그인 화면)  또는  (다이얼러  또는  통화 화면  또는  회의실)│
└──────────────────────────────────────────────────────────────┘
```

### 레이아웃 구성

| 영역 | 크기 | 역할 |
|------|------|------|
| TitleBar | 36px | 트래픽 라이트 (red/yellow/green), 앱 이름, 상태 알림 |
| Sidebar | 220px | 내선 선택, SIP 상태, 설정, 도움말 |
| Content | 나머지 | 페이지별 콘텐츠 (로그인/다이얼러/통화/회의) |

---

## 2. 공통 컴포넌트

### 2.1 TitleBar (트래픽 라이트 포함)

| 요소 | 동작 |
|------|------|
| 빨간 버튼 | 앱 종료 |
| 노란 버튼 | 최소화 |
| 초록 버튼 | 전체 화면/일반 전환 |
| 앱 이름 | `Kibal` |
| 알림 아이콘 | SIP 등록/통화 상태 알림 |
| 설정 메뉴 | `…` (스택 메뉴) |

### 2.2 Sidebar

| 항목 | 상태 | 동작 |
|------|------|------|
| 내선 선택 | `1101` ~ `1104` | 클릭 시 SIP 재등록 |
| 등록 상태 | `등록됨/등록 안 됨` | 아이콘 색상 변경 |
| 마이크 | 🔴/🔵/🔘 | 토글 |
| 카메라 | 🔴/🔵/🔘 | 토글 |
| 설정 | ⚙️ | 설정 화면 |
| 정보 | ℹ️ | 도움말/버전 |

### 2.3 통화 중 화면 (CallView)

| 요소 | 동작 |
|------|------|
| 로컬 영상 | 화면 왼쪽 상단, 280×210 |
| 원격 영상 | 메인 영역, 전체 응답 |
| 마이크 버튼 | 토글 (🔴=음소거) |
| 카메라 버튼 | 카메라 전환 (전면/후면) |
| 종료 버튼 | 전화 끊기 |
| 키패드 | 숫자 입력 (선택) |

---

## 3. 화면별 설계

### 3.1 로그인 화면 (LoginView)

| 요소 | 설명 |
|------|------|
| SIP 서버 | 도메인/IP 입력 (기본값 `192.168.11.2`, port `5060`) |
| 사용자 이름 | 내선 번호 (기본값 `1101`) |
| 비밀번호 | 비밀번호 입력 |
| 등록 버튼 | `REGISTER` 실행 |
| 가입 취소 | 등록 해제 |
| 오류 표시 | 등록 실패 시 오류 메시지 |

**플로우**
1. 사용자 입력 → `SipProvider` 상태 업데이트
2. `SipClient.register()` 호출
3. `onRegistrationSucceeded` → Sidebar 상태 `등록됨`
4. `onRegistrationFailed` → 오류 메시지 표시

---

### 3.2 다이얼러 (DialerView)

| 요소 | 설명 |
|------|------|
| 내선 선택 | 기존 내선 (1101~1104) |
| 다이얼 패널 | 숫자 키패드, 이모티콘, 음성 인식(선택) |
| 발신 버튼 | `CALL` |
| 중단 버튼 | 통화 취소/끼어들기 |

**플로우**
1. 번호 입력 후 `발신` 클릭
2. `SipClient.makeCall(target)`
3. `CallStateListener`에서 `Ringing` → 원격 응답 대기
4. `Connected` → CallView로 전환
5. `Disconnected` → DialerView 복귀

---

### 3.3 통화 화면 (CallView)

| 요소 | 설명 |
|------|------|
| 로컬 영상 | 전면 카메라 (Ringing/통화 중) |
| 원격 영상 | 상대방 영상 (환영 카드, 상태 배너) |
| 마이크 토글 | 아이콘 애니메이션 |
| 카메라 토글 | 전면↔후면 |
| 화면 전체 모드 | 전체 화면 (Option+Command+F) |
| 종료 | `BYE` → DialerView 복귀 |

**상태별 표시**

| 상태 | 표시 |
|------|------|
| Ringing | 상대측 `Ringing` 배너 + 로컬 미리보기 |
| Connected | 상대 영상 + 제어 버튼 |
| Disconnected | 알림 + DialerView 복귀 |

---

### 3.4 회의실 화면 (ConferenceView)

| 요소 | 설명 |
|------|------|
| 참가자 타일 | 최대 4명 (확대 시 스크롤 가능) |
| 참가자 목록 | 테이블 뷰, 원거리 상태 |
| 내 영상 | 화면 오른쪽 상단 (항상 표시) |
| 마이크/카메라 | 전체 참가자 버튼 |
| 종료 | 회의 종료 |

**플로우**
1. `SipClient.joinConference(roomId)`
2. `ConferenceManager`에서 참가자 추적
3. `onTrack` → RemoteVideoTile 추가
4. 참가자 추가/제거 → 타일 업데이트

---

### 3.5 설정 화면 (SettingsView)

| 항목 | 설명 |
|------|------|
| 서버 정보 | SIP 도메인, 포트, WS 주소 |
| 계정 | 내선, 사용자 이름, 표시명 |
| 보안 | TLS/WSS, 인증서 확인 |
| 미디어 | 해상도, 프레임레이트, 코덱 (담당자 결정) |
| 알림 | 푸시 알림, 배지, 사운드 |
| 디버깅 | 로그 레벨, 진단 정보 내보내기 |

---

## 4. macOS 네이티브 기능

| 기능 | 구현 방법 | 상태 |
|------|-----------|------|
| 상태 표시줄 아이콘 | `NSStatusItem` + `NSMenu` | 최초 구현 |
| 전역 단축키 | `NSWorkspace` + `HotKey` | 최초 구현 |
| Dock 아이콘 | Flutter 기본 | ✅ |
| UIElement | Flutter `UrandWidget` | 최초 구현 |
| 자동 업데이트 | Sparkle / custom | P2 |
| macOS 로그인 키체인 | `flutter_secure_storage` | P2 |
| 시스템 알림 | `UserNotifications` | P2 |

---

## 5. macOS 권한 요구사항

| 권한 | 설명 | 런타임 확인 |
|------|------|-------------|
| 카메라 | `NSCameraUsageDescription` | `permission_handler` + macOS 전용 |
| 마이크 | `NSMicrophoneUsageDescription` | `permission_handler` + macOS 전용 |
| 접근성 | (선택) 전화 제어 | 최초 구현 시 검토 |
| 화면 공유 | (선택) 화면 전송 | P1 |

**macOS 권한 다이얼로그 흐름**
1. 첫 카메라/마이크 사용 시 `permission_handler`가 시스템 권한 다이얼로그 표시
2. 사용자가 거부 시 앱이 차단되고, 설정에서 변경 유도
3. 다이얼로그는 `Info.plist`의 설명문에 기반해 표시

---

## 6. 디자인 시스템

| 항목 | 값 |
|------|-----|
| Primary | `#1D4ED8` (blue-700) |
| Secondary | `#3B82F6` (blue-500) |
| Surface | `#FFFFFF` |
| Background | `#F8FAFC` |
| Text primary | `#111827` |
| Text secondary | `#6B7280` |
| Error | `#DC2626` |
| Success | `#16A34A` |
| Warning | `#D97706` |

---

## 7. 파일 구조

```text
macos-client/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   └── src/
│       ├── sip/
│       ├── media/
│       ├── providers/
│       ├── ui/
│       │   ├── main_view.dart
│       │   ├── screens/
│       │   │   ├── login_view.dart
│       │   │   ├── dialer_view.dart
│       │   │   ├── call_view.dart
│       │   │   └── conference_view.dart
│       │   └── common/
│       └── utils/
├── macos/
├── windows/
└── pubspec.yaml
```

---

## 8. 관련 문서

- [[wiki/02_Design/macOS-client-design]] — macOS 설계 (Flutter 기반)
- [[wiki/02_Design/mobile-client]] — Flutter Mobile Client 설계
- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/01_Projects/client-project-plan]] — Kibal Client 프로젝트 계획
