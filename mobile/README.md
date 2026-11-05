# Kibal Mobile Client

**SmartCC Kibal Mobile Client** - Flutter 기반 SIP 영상통화 클라이언트

> **프로젝트**: SmartCC_Kibal-Client (Mobile)
> **버전**: 0.1.0
> **작성일**: 2026-11-03
> **상태**: 개발 중

---

## 📋 개요

Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 **Flutter 기반 Mobile SIP 클라이언트**입니다.
Web Client(React + SIP.js)와 동일한 기능(1:1 영상통화, 다자간 회의)을 제공합니다.

---

## 🎯 목표

- [x] **CT03**: Flutter SIP 등록 (Mobile)
- [ ] **CT04**: 1:1 영상통화 (Mobile)
- [ ] **CT06**: NAT 통과 (STUN/TURN)

---

## 🚀 빠른 시작

### **사전 요구사항**

| 도구 | 버전 | 설치 확인 명령 |
|------|------|----------------|
| Flutter SDK | 3.19+ | `flutter --version` |
| Dart SDK | 3.0+ | `dart --version` |
| Xcode | 15.x+ | `xcodebuild -version` |
| Java JDK | 17+ | `java -version` |
| Android Studio | Latest | - |

### **설치**

```bash
# 1. 의존성 설치
cd mobile
flutter pub get

# 2. iOS 설정 (macOS)
cd ios
pod install
cd ..

# 3. Android 설정 (선택)
# Android Studio에서 SDK 설정
```

### **실행**

```bash
# 개발 모드
flutter run

# iOS 시뮬레이터
flutter run -d iPhone

# Android 에뮬레이터
flutter run -d Pixel

# 릴리즈 빌드 (Android)
flutter build appbundle

# 릴리즈 빌드 (iOS)
flutter build ios --release --no-codesign
```

---

## 📁 프로젝트 구조

```
mobile/
├── lib/
│   ├── main.dart                    # Flutter 엔트리 포인트
│   ├── app.dart                     # MaterialApp + 라우팅
│   └── src/
│       ├── sip/                     # SIP 클라이언트
│       │   ├── sip_config.dart      # SIP 설정 모델
│       │   ├── sip_client.dart      # SIP 클라이언트 클래스
│       │   └── sip_session.dart     # SIP 세션 관리
│       ├── media/                   # WebRTC 미디어
│       │   ├── media_manager.dart   # 미디어 스트림 관리
│       │   └── webrtc_helpers.dart  # WebRTC 헬퍼
│       ├── ui/                      # UI 화면
│       │   ├── login/               # SIP 등록 화면
│       │   │   └── login_screen.dart
│       │   ├── dialer/              # 다이얼러 화면
│       │   │   └── dialer_screen.dart
│       │   ├── call/                # 통화 화면
│       │   │   └── call_screen.dart
│       │   └── common/              # 공통 위젯
│       │       ├── video_view.dart
│       │       └── sip_status_bar.dart
│       ├── providers/               # 상태 관리
│       │   ├── sip_provider.dart
│       │   └── media_provider.dart
│       └── utils/                   # 유틸리티
│           ├── constants.dart
│           └── formatters.dart
├── android/                         # Android 네이티브
│   └── app/src/main/
│       └── AndroidManifest.xml      # Android 권한
├── ios/                             # iOS 네이티브
│   └── Runner/
│       ├── Info.plist              # iOS 권한
│       └── Base.lproj/
│           └── LaunchScreen.storyboard
├── pubspec.yaml                     # 의존성 관리
└── README.md
```

---

## 🔌 SIP 서버 연결

### **개발 환경 (DEV)**
```
도메인: 127.0.0.1
포트: 5060 (UDP)
WebSocket: ws://127.0.0.1:8088/ws
전송: UDP
```

### **프로덕션 환경 (PRD)**
```
도메인: 192.168.11.2
포트: 5060 (UDP)
WebSocket: ws://192.168.11.2:8088/ws
전송: UDP
```

### **계정 정보**
| 내선 | 비밀번호 | 용도 |
|------|----------|------|
| 1001 | (NAS PRD .env) | UDP/PJSIP (Mobile) |
| 1002 | (NAS PRD .env) | UDP/PJSIP (Mobile) |
| 1101 | (NAS PRD .env) | WebRTC/WebSocket |
| 1102 | (NAS PRD .env) | WebRTC/WebSocket |

---

## 📱 지원 플랫폼

| 플랫폼 | 상태 | 비고 |
|--------|------|------|
| **Android** | ✅ 지원 | API 21+ (Android 5.0+) |
| **iOS** | ✅ 지원 | iOS 12.0+ |
| **Web** | ❌ 미지원 | Web은 별도 React Client 사용 |

---

## 🔧 환경 설정

### **iOS 권한 설정**
`ios/Runner/Info.plist`에 다음 권한을 추가해야 합니다:
- 카메라 접근 (`NSCameraUsageDescription`)
- 마이크 접근 (`NSMicrophoneUsageDescription`)
- 백그라운드 실행 (`UIBackgroundModes`)

### **Android 권한 설정**
`android/app/src/main/AndroidManifest.xml`에 다음 권한을 추가해야 합니다:
- 카메라 (`android.permission.CAMERA`)
- 녹음 (`android.permission.RECORD_AUDIO`)
- 인터넷 (`android.permission.INTERNET`)
- 포그라운드 서비스 (`android.permission.FOREGROUND_SERVICE`)

---

## 🧪 테스트

### **CT03: SIP 등록 테스트**
```bash
# 1. 앱 실행
flutter run

# 2. 계정 입력
# - 내선: 1001
# - 비밀번호: (PRD 비밀번호)
# - 도메인: 192.168.11.2
# - 포트: 5060

# 3. 등록 클릭
# 4. 상태 확인: "등록됨"

# 5. Asterisk에서 확인
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show contacts"'
```

### **CT04: 1:1 영상통화 테스트**
```bash
# 1. 단말 A: 1001 등록
# 2. 단말 B: 1002 등록
# 3. A에서 B로 호출
# 4. B에서 수신
# 5. 양쪽 영상/오디오 확인
```

---

## 📊 PoC 테스트 체크리스트

| 테스트 ID | 설명 | 상태 |
|-----------|------|------|
| CT01 | SIP.js 등록 (Web) | ✅ PASS |
| CT02 | 1:1 영상통화 (Web) | ✅ PASS |
| CT03 | Flutter SIP 등록 (Mobile) | ⏳ **개발 중** |
| CT04 | 1:1 영상통화 (Mobile) | ⏳ **대기** |
| CT05 | 3자 SFU 회의 (Web) | ✅ PASS |
| CT06 | NAT 통과 (STUN) | ⏳ **미구성** |

---

## 📚 관련 문서

- [PoC 테스트 절차 안내서](../../wiki/03_Guides/PoC_테스트_절차_안내서_20261103.md)
- [Mobile Client 설계](../../wiki/02_Design/mobile-client.md)
- [클라이언트 프로젝트 계획](../../wiki/01_Projects/client-project-plan.md)
- [Asterisk 서버 운영 가이드](../../wiki/03_Guides/Asterisk_서버_운영관리_가이드_20261103.md)

---

## 🤖 AI Agent 정보

- **생성자**: TVS (Mistral Vibe)
- **생성일**: 2026-11-03
- **연관**: [SmartCC_Kibal-Client Wiki](../../wiki/)

---

## 📝 라이선스

본 프로젝트는 SmartCC Kibal 프로젝트의 일부이며, 내부용으로만 사용됩니다.
