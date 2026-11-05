# CT03·CT04 Mobile Client 개발 작업계획서

| 항목 | 내용 |
|------|------|
| **문서 ID** | PLAN-CT03CT04-20261103-001 |
| **프로젝트** | SmartCC_Kibal-Client (Mobile) |
| **작성일** | 2026-11-03 |
| **버전** | v1.0 |
| **상태** | **개발 시작 준비** |
| **관련 PoC** | [[wiki/03_Guides/PoC_테스트_절차_안내서_20261103]] §5-6 |
| **관련 계획** | [[wiki/01_Projects/client-project-plan]] §7 (Stage C3) |
| **관련 설계** | [[wiki/02_Design/mobile-client]] |
| **작업 이력** | [[docs/_작업이력/2026-11-03]] |
| **로그** | [[wiki/07_Logs/작업로그_20261103]] |

---

## 📋 **1. 개요**

본 작업계획서는 **SmartCC Kibal** 프로젝트의 **Mobile Client (Flutter)** 개발을 위한 상세 실행 계획을 정의합니다.
**CT03 (Flutter SIP 등록)**과 **CT04 (1:1 영상통화 Mobile)**을 통과하기 위한 모든 작업을 포함합니다.

> **배경**: 2026-11-03 현재 `mobile/` 디렉토리가 존재하지 않아 CT03·CT04가 **BLOCKED** 상태입니다.
> **목표**: Flutter 기반 Mobile SIP 클라이언트를 구현하여 **CT03 → CT04 순차 통과**

---

## 🎯 **2. 개발 목표**

### **2.1 PoC 테스트 통과**
| 테스트 ID | 설명 | 목표 상태 | 현재 상태 |
|-----------|------|-----------|-----------|
| **CT03** | Flutter SIP 등록 (Mobile) | ✅ **PASS** | ❌ **BLOCKED** |
| **CT04** | 1:1 영상통화 (Mobile) | ✅ **PASS** | ❌ **BLOCKED** |

### **2.2 구체적 목표**
- [ ] Flutter 프로젝트 초기화 (`mobile/` 디렉토리 생성)
- [ ] SIP 등록 기능 구현 (UDP/PJSIP 또는 WebRTC/WebSocket)
- [ ] WebRTC 미디어 스트림 처리
- [ ] 카메라/마이크 권한 설정 (iOS/Android)
- [ ] SIP.js 서버(`192.168.11.2:8088/ws`)와 연동
- [ ] Asterisk PRD에서 Mobile contact 확인
- [ ] 1:1 영상통화 (Mobile ↔ Mobile 또는 Mobile ↔ Web)

---

## 🏗️ **3. 기술 스택**

### **3.1 핵심 라이브러리**
| 라이브러리 | 버전 | 용도 | 의존성 |
|-----------|------|------|--------|
| **flutter** | 3.x | Flutter Framework | 🔴 필수 |
| **flutter_webrtc** | 0.11+ | WebRTC (카메라/마이크/스트림) | 🔴 필수 |
| **flutter_sip** | 0.0.7+ | SIP User Agent (PJSIP 래퍼) | 🔴 필수 |
| **provider** | 6.1+ | 상태 관리 | 🟡 권장 |
| **permission_handler** | 11+ | 권한 요청 | 🟡 권장 |
| **go_router** | 15+ | 라우팅 | ⚪ 선택 |

### **3.2 개발 환경**
| 환경 | 버전 | 용도 | 비고 |
|------|------|------|------|
| **macOS** | 26.7.1+ | 개발 플랫폼 | ✅ **준비됨** |
| **Xcode** | 15.x+ | iOS 빌드/시뮬레이터 | ❌ **미설치** |
| **Android Studio** | Latest | Android 에뮬레이터 | ⚪ **선택** |
| **Java JDK** | 17+ | Android 빌드 | ❌ **미설치** |
| **Flutter SDK** | 3.19+ | Flutter CLI | ❌ **미설치** |

---

## 📁 **4. 프로젝트 구조**

```
mobile/
├── lib/
│   ├── main.dart                    ← Flutter 엔트리 포인트
│   ├── app.dart                     ← MaterialApp + 라우팅
│   ├── src/
│   │   ├── sip/
│   │   │   ├── sip_client.dart     ← SIP 등록/발신/수신
│   │   │   ├── sip_session.dart    ← 세션 관리
│   │   │   └── sip_config.dart     ← SIP 설정 모델
│   │   ├── media/
│   │   │   ├── media_manager.dart  ← flutter_webrtc 래퍼
│   │   │   └── webrtc_helpers.dart ← 헬퍼 함수
│   │   ├── ui/
│   │   │   ├── login/              ← SIP 등록 화면
│   │   │   │   └── login_screen.dart
│   │   │   ├── dialer/             ← 다이얼러 화면
│   │   │   │   └── dialer_screen.dart
│   │   │   ├── call/               ← 1:1 통화 화면
│   │   │   │   └── call_screen.dart
│   │   │   └── common/            ← 공통 위젯
│   │   │       ├── video_view.dart
│   │   │       └── sip_status_bar.dart
│   │   ├── providers/
│   │   │   ├── sip_provider.dart   ← SIP 상태 관리
│   │   │   └── media_provider.dart ← 미디어 상태
│   │   └── utils/
│   │       ├── constants.dart      ← SIP 도메인/포트
│   │       └── formatters.dart     ← 포맷 유틸
│   └── l10n/                        ← 다국어 (한국어/영어)
│       └── app_localizations.dart
├── android/                         ← Android 네이티브
│   ├── app/
│   │   └── src/main/
│   │       ├── AndroidManifest.xml ← **권한 설정**
│   │       └── java/...            ← 네이티브 코드
├── ios/                             ← iOS 네이티브
│   ├── Runner/
│   │   ├── Info.plist             ← **권한 설정**
│   │   └── Base.lproj/            ← LaunchScreen
├── pubspec.yaml                     ← **의존성 관리**
├── Dockerfile                       ← (선택) 빌드용
└── README.md
```

---

## 🚀 **5. 구현 계획**

### **5.1 Phase 1: 프로젝트 초기화 (0.5일)**
| 작업 | 상세 | 산출물 | 검증 |
|------|------|--------|------|
| Flutter 프로젝트 생성 | `flutter create mobile` | `mobile/` 디렉토리 | ✅ `flutter doctor` |
| 의존성 추가 | `pubspec.yaml`에 라이브러리 추가 | `pubspec.yaml` | ✅ `flutter pub get` |
| Git 초기화 | `.gitignore` 생성 | `.gitignore` | ✅ `git status` |

**command:**
```bash
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client
flutter create mobile
cd mobile
# pubspec.yaml에 의존성 추가
flutter pub get
```

### **5.2 Phase 2: SIP 클라이언트 구현 (1일)**
| 작업 | 상세 | 산출물 | 검증 |
|------|------|--------|------|
| SIP 설정 모델 | 도메인, 포트, 사용자 정보 모델 | `sip_config.dart` | ✅ 타입 정의 |
| SIP 클라이언트 클래스 | `flutter_sip` 초기화 및 관리 | `sip_client.dart` | ✅ 인스턴스 생성 |
| SIP 등록 기능 | `register()` / `unregister()` 구현 | `sip_client.dart` | ✅ REGISTER 전송 |
| SIP 통화 기능 | `call()` / `hangup()` / `accept()` 구현 | `sip_client.dart` | ✅ INVITE 전송 |

**code example (sip_client.dart):**
```dart
import 'package:flutter_sip/flutter_sip.dart';

class KibalSipClient {
  late SIPClient _client;
  
  Future<void> init(String username, String password, String domain, int port) async {
    await _client.init(SIPSettings(
      username: username,
      domain: domain,
      password: password,
      transportType: SingleVideoTransportType.udp,
      port: port,
    ));
  }
  
  Future<void> register() => _client.register();
  Future<void> unregister() => _client.unregister();
  Future<void> call(String target) => _client.call(target);
  Future<void> hangup() => _client.hangup();
}
```

### **5.3 Phase 3: WebRTC 미디어 처리 (0.5일)**
| 작업 | 상세 | 산출물 | 검증 |
|------|------|--------|------|
| WebRTC 초기화 | `flutter_webrtc` 설정 | `media_manager.dart` | ✅ 카메라/마이크 접근 |
| 로컬 스트림 획득 | `getUserMedia()` 구현 | `media_manager.dart` | ✅ `MediaStream` 얻기 |
| 원격 스트림 관리 | `onTrack` 이벤트 처리 | `media_manager.dart` | ✅ 원격 스트림 표시 |
| 비디오 렌더러 | `RTCVideoRenderer` 위젯 | `video_view.dart` | ✅ 영상 표시 |

**code example (media_manager.dart):**
```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaManager {
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  
  Future<MediaStream> getUserMedia() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    return _localStream!;
  }
  
  void onTrack(MediaStreamTrack track, String socketId) {
    if (track.kind == 'video') {
      _remoteStreams[socketId] = MediaStream()..addTrack(track);
    }
  }
  
  void dispose() {
    _localStream?.dispose();
    _remoteStreams.values.forEach((s) => s.dispose());
  }
}
```

### **5.4 Phase 4: UI 개발 (1일)**
| 화면 | 기능 | 산출물 | 검증 |
|------|------|--------|------|
| 로그인 화면 | SIP 계정 입력, 등록/해제 | `login_screen.dart` | ✅ 등록 상태 표시 |
| 다이얼러 화면 | 번호 입력, 통화 시작 | `dialer_screen.dart` | ✅ 통화 연결 |
| 통화 화면 | 영상 표시, 통화 종료 | `call_screen.dart` | ✅ 영상/오디오 확인 |
| 공통 위젯 | 비디오 뷰, 상태 바 | `common/` | ✅ UI 일관성 |

**UI 구조:**
```
┌─────────────────────────────────┐
│  [Kibal Mobile]                 │
├─────────────────────────────────┤
│  📞 다이얼러                     │
│  ┌─────────────────────────┐   │
│  │ 🔢 1 🔢 2 🔢 3 🔢       │   │
│  │ 🔢 4 🔢 5 🔢 6 🔢       │   │
│  │ 🔢 7 🔢 8 🔢 9 🔢       │   │
│  │   🔢 * 🔢 0 🔢 # 🔢     │   │
│  └─────────────────────────┘   │
│  [  1102  ] [호출]           │
├─────────────────────────────────┤
│  상태: 등록됨                   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  [통화 중]                      │
├─────────────────────────────────┤
│  ┌─────────────┐                │
│  │             │ ← 로컬 영상     │
│  │   📹       │ (작은 창)        │
│  │             │                │
│  └─────────────┘                │
│                                  │
│  ┌─────────────────────────┐   │
│  │                         │ ← 원격 영상  │
│  │       🎥              │ (메인 화면)    │
│  │                         │              │
│  └─────────────────────────┘   │
├─────────────────────────────────┤
│  [음소거] [스피커] [통화 종료]   │
└─────────────────────────────────┘
```

### **5.5 Phase 5: 권한 설정 (0.5일)**
| 플랫폼 | 파일 | 필수 권한 | 비고 |
|--------|------|-----------|------|
| **iOS** | `ios/Runner/Info.plist` | 카메라, 마이크, 백그라운드 | VoIP 모드 활성화 |
| **Android** | `android/app/src/main/AndroidManifest.xml` | 카메라, 녹음, 포그라운드 서비스 | Wayland 권한 |

**iOS Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>영상통화를 위해 카메라 접근이 필요합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>영상통화를 위해 마이크 접근이 필요합니다</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
</array>
```

**Android AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## ⏱️ **6. 타임라인**

### **6.1 일별 계획**

| 날짜 | Phase | 작업 | 예상 시간 | 완료 기준 |
|------|-------|------|-----------|-----------|
| **2026-11-03** | **환경 설정** | Flutter/Xcode/Java 설치 | 2-3시간 | `flutter doctor` 모든 체크 통과 |
| **2026-11-03** | **Phase 1** | Flutter 프로젝트 초기화 | 0.5일 | `mobile/` 디렉토리 생성 완료 |
| **2026-11-03** | **Phase 2** | SIP 클라이언트 구현 | 1일 | SIP 등록 테스트 준비 완료 |
| **2026-11-04** | **Phase 3** | WebRTC 미디어 처리 | 0.5일 | 카메라/마이크 스트림 확인 |
| **2026-11-04** | **Phase 4** | UI 개발 | 1일 | 모든 화면 구현 완료 |
| **2026-11-04** | **Phase 5** | 권한 설정 | 0.5일 | iOS/Android 권한 요청 확인 |
| **2026-11-05** | **테스트** | CT03 (SIP 등록) | 0.5일 | Asterisk에서 contact 확인 |
| **2026-11-05** | **테스트** | CT04 (1:1 통화) | 0.5일 | 양방향 영상/오디오 확인 |

### **6.2 마일스톤**
| 마일스톤 | 목표 | 예정일 | 상태 |
|----------|------|--------|------|
| **M1** | Flutter 프로젝트 초기화 | 2026-11-03 | ⏳ **진행 중** |
| **M2** | SIP 클라이언트 구현 완료 | 2026-11-04 | ⏳ **대기** |
| **M3** | UI 구현 완료 | 2026-11-04 | ⏳ **대기** |
| **M4** | **CT03 통과** | 2026-11-05 | ⏳ **대기** |
| **M5** | **CT04 통과** | 2026-11-05 | ⏳ **대기** |

---

## ⚠️ **7. 위험 요소 및 완화 전략**

### **7.1 기술적 위험**
| 위험 | 영향 | 확률 | 완화 전략 |
|------|------|------|------------|
| **Flutter 설치 실패** | 개발 시작 지연 | Low | 공식 가이드 따라서 설치 |
| **flutter_sip 호환성 문제** | SIP 등록 실패 | Medium | 대안 라이브러리(`dart_sip`) 검토 |
| **iOS 시뮬레이터 문제** | iOS 테스트 어려움 | Medium | 실기기 사용 or Android 우선 테스트 |
| **Android 에뮬레이터 성능** | 테스트 지연 | Medium | 물리 디바이스 사용 |
| **Asterisk UDP 포트 차단** | SIP 등록 실패 | Low | NAS 방화벽 확인 (`5060/udp`) |

### **7.2 개발 환경 위험**
| 위험 | 영향 | 완화 전략 |
|------|------|------------|
| **Xcode 미설치** | iOS 빌드 불가 | App Store에서 Xcode 설치 |
| **Java JDK 미설치** | Android 빌드 불가 | [oracle.com/java](https://www.oracle.com/java/)에서 설치 |
| **Android Studio 미설치** | 에뮬레이터 사용 불가 | 실기기 테스트 or Android Studio 설치 |

### **7.3 테스트 환경 위험**
| 위험 | 영향 | 완화 전략 |
|------|------|------------|
| **iOS 디바이스 부재** | iOS 테스트 어려움 | Android 우선 테스트, 후에 iOS 검증 |
| **Android 디바이스 부재** | Android 테스트 어려움 | 에뮬레이터 사용 or 물리 디바이스 준비 |
| **PRD 서버 접근 제한** | 테스트 불가능 | NAS2 SSH 접근 확인 |

---

## ✅ **8. 성공 기준**

### **8.1 CT03 통과 기준**
- [ ] Flutter 앱이 `192.168.11.2:5060`(UDP) 또는 `192.168.11.2:8088/ws`(WebSocket)으로 SIP REGISTER 전송
- [ ] Asterisk PRD에서 `pjsip show contacts`에 Mobile contact(`1001`~`1004`) 확인
- [ ] 앱 상태가 **"등록됨"**으로 표시
- [ ] 등록 해제 후 contact 제거 확인
- [ ] **증거**: 앱 스크린샷, `pjsip show contacts` 출력

### **8.2 CT04 통과 기준**
- [ ] Mobile 단말 2대가 SIP 등록 성공 (CT03 통과 전제)
- [ ] 단말 A에서 단말 B로 호출 시 양쪽 세션 **Established**
- [ ] 양방향 오디오·영상 확인 (H.264 코덱)
- [ ] 통화 종료 후 세션 정리 확인
- [ ] **증거**: 양쪽 단말 스크린샷, `core show channels` 출력, `sngrep` 캡처

---

## 📊 **9. 리소스 요구사항**

### **9.1 인적 리소스**
| 역할 | 필요 인원 | 기간 | 비고 |
|------|-----------|------|------|
| Flutter 개발자 | 1명 | 2-3일 | 전담 개발 |
| Asterisk 운영자 | 1명 | 0.5일 | PRD 서버 확인 지원 |
| 테스터 | 1명 | 0.5일 | Mobile 디바이스 테스트 |

### **9.2 하드웨어 리소스**
| 자원 | 필요 사양 | 비고 |
|------|-----------|------|
| **개발 머신** | macOS 26.7.1+, 8GB RAM+, 256GB SSD+ | ✅ **준비됨** |
| **iOS 디바이스** | iPhone/iPad (iOS 15+) | ⚪ **선택** |
| **Android 디바이스** | Android 10+ | ⚪ **선택** |
| **PRD 서버** | NAS2 (`kibal-prd-asterisk`) | ✅ **준비됨** |

### **9.3 소프트웨어 리소스**
| 소프트웨어 | 버전 | 라이선스 | 비고 |
|-----------|------|--------|------|
| Flutter SDK | 3.19+ | BSD | ❌ **미설치** |
| Xcode | 15.x+ | Apple | ❌ **미설치** |
| Android Studio | Latest | Apache 2.0 | ⚪ **선택** |
| Java JDK | 17+ | GPL | ❌ **미설치** |

---

## 📝 **10. 관련 문서 및 참조**

### **10.1 프로젝트 문서**
| 문서 | 위치 | 설명 |
|------|------|------|
| PoC 테스트 절차 | [[wiki/03_Guides/PoC_테스트_절차_안내서_20261103]] | CT01~CT06 실행 절차 |
| 클라이언트 프로젝트 계획 | [[wiki/01_Projects/client-project-plan]] | 전체 프로젝트 로드맵 |
| Mobile Client 설계 | [[wiki/02_Design/mobile-client]] | 기술 설계 및 아키텍처 |
| Asterisk 운영 가이드 | [[wiki/03_Guides/Asterisk_서버_운영관리_가이드_20261103]] | 서버 관리 및 모니터링 |

### **10.2 External Resources**
| 리소스 | URL | 용도 |
|--------|-----|------|
| Flutter 공식 문서 | [flutter.dev/docs](https://flutter.dev/docs) | Flutter 개발 가이드 |
| flutter_sip GitHub | [github.com/cloudwebrtc/flutter_sip](https://github.com/cloudwebrtc/flutter_sip) | SIP 라이브러리 문서 |
| flutter_webrtc GitHub | [github.com/cloudwebrtc/flutter_webrtc](https://github.com/cloudwebrtc/flutter_webrtc) | WebRTC 라이브러리 문서 |

---

## 🔄 **11. 동기화 및 버전 관리**

### **11.1 Git Workflow**
```bash
# 1. 작업 시작 시
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client
git checkout -b feature/mobile-ct03-ct04

# 2. 변경 사항 커밋
./scripts/git-sync.sh --auto --no-deploy

# 3. PR 생성 및 병합 (GitHub)
# 4. 3-Way 동기화 (github → dev → prd)
./scripts/git-sync.sh --auto --deploy
```

### **11.2 문서 동기화**
| 문서 | 동기화 시점 | 비고 |
|------|-------------|------|
| 작업계획서 | **오늘 (2026-11-03)** | 본 문서 |
| 작업이력 | 매일 | `docs/_작업이력/YYYY-MM-DD.md` |
| 로그 | 실시간 | `wiki/07_Logs/작업로그_YYYYMMDD.md` |
| 보고서 | 완료 시 | `wiki/06_Reports/` |

---

## 📅 **12. 문서 이력**

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-11-03 | TVS (Mistral Vibe) | 최초 작성 |

---

## 🚀 **13. 다음 단계**

### **13.1 즉시 실행 (2026-11-03)**
1. **Flutter SDK 설치** (2-3시간)
2. **Xcode 설치** (App Store, 20-30분)
3. **Java JDK 설치** (5-10분)
4. **Flutter 프로젝트 초기화** (0.5시간)
5. **SIP 클라이언트 구현 시작** (1시간)

### **13.2 단기 목표 (2026-11-05까지)**
- [ ] **CT03 통과** (Flutter SIP 등록)
- [ ] **CT04 통과** (Mobile 1:1 영상통화)
- [ ] **Web + Mobile 통합 테스트**

### **13.3 중기 목표 (2026-11-07까지)**
- [ ] **CT06 준비** (NAT/STUN/TURN 구성)
- [ ] **Mobile SFU 회의 지원** (3자 이상)
- [ ] **화면 공유 기능 추가** (선택)

---

*본 문서는 SmartCC Kibal 프로젝트의 Mobile Client (CT03·CT04) 개발을 위한 작업계획서입니다.*
*문서는 Wiki 구조에 따라 `wiki/06_Reports/`에 저장되며, Git 3-Way 동기화를 통해 모든 remote에 반영됩니다.*
