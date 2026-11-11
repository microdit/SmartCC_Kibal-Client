# macOS Client 설계 (Native macOS SIP Client)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v3.0 (2026-11-12 현행화) |
| **상태** | 구현·운영 중 — v0.0.17 (Flutter + sip_ua 포크 + flutter_webrtc) |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/cross-platform-client-design]], ADR-004~006 |

---

## 0. 현행 아키텍처 (2026-11-12 기준, 최우선 참조)

> 아래 1~8장의 Swift/PJSIP·flutter_sip 설계는 **이력 자료**다. 실제 구현은 본 장을 따른다.

| 영역 | 현행 구현 | 근거 |
|------|----------|------|
| 앱 | Flutter macOS desktop (`macos-client/`), GoRouter, Provider | ADR-004 |
| SIP | `sip_ua` **로컬 포크** `macos-client/packages/sip_ua` (WS 8088) | ADR-004, ADR-005 |
| 미디어 | `flutter_webrtc 1.6.3`, unified-plan, DTLS-SRTP, opus 우선 | G6 |
| 서버 | Asterisk 22 LTS Docker(`kibal-dev-asterisk`), ConfBridge SFU 6000 | 서버 리포 |
| 서버 주소 | OPS `GET /api/client/config` → `server_config.dart`(로그인 화면 자동/수동 갱신) | 2026-11-11 |
| 로그 | `RemoteLogForwarder` → OPS `POST /api/client-logs`(X-Client-Key, offset 재전송) | v0.0.12~13 |
| 빌드/발행 | `scripts/build_macos.sh`, `scripts/release_macos.sh` | 2026-11-12 |

### 0.1 핵심 컴포넌트 (파일)

| 파일 | 역할 |
|------|------|
| `lib/src/sip/sip_client.dart` | 등록/발신/수신, re-INVITE 자동 수락(H5), 원격 트랙 복구(H1), 30초 미디어·영상 요약, ADR-006 recvonly, transceiver 진단 |
| `packages/sip_ua/lib/src/rtc_session.dart` | 포크 수정: ICE 후보 172.16/12 보정(ADR-005), G1 수신 영상 판정, G2 answer 스트림 분리, G3 in-dialog 타임아웃 허용 |
| `lib/src/media/media_manager.dart` | 트랙별 렌더 스트림, 최신 3타일, 유효 트랙 정리 |
| `lib/src/ui/conference/conference_screen.dart` | 6000~6999 카드형 회의 화면, 참가자 선택 |
| `lib/src/utils/server_config.dart` | OPS 서버 설정 탐색(저장값→입력 도메인→MacPro.local→기본) |
| `lib/src/utils/remote_log_forwarder.dart` | 로그 업로드(모드: 끄기~전체), `server-config.json`/offset 관리 |

### 0.2 통화 흐름 요약

1. 로그인 화면 → OPS `/api/client/config`로 `sip_domain`/`ws_server` 갱신 → REGISTER
2. 발신: 카메라 있으면 sendrecv, **없으면 audio + video recvonly**(ADR-006, v0.0.17)
3. ConfBridge 입장 → 서버 re-INVITE(영상 스트림 추가) → 자동 수락 → 참가자 타일
4. 30초마다 `SIP media summary`/`SIP video summary` → OPS

### 0.3 네트워크 전제 (2026-11-12)

- 서버 MacPro 유선 `192.168.0.3`(192.168.0.0/24), `MEDIA_ADDRESS=192.168.0.3`
- Docker Desktop NAT로 서버에서 보이는 단말 주소는 `172.19.0.1`(정상), ICE 후보는 ADR-005로 보정
- PRD NAS(`nas2`=192.168.11.2)는 현 대역에서 미도달


## 1. 설계 배경

Web Client가 주력이지만, 일부 고객사(특히 금융/증권)의 경우 **네이티브 macOS 앱**이 필요할 수 있습니다.

- **배포 방식**: Mac App Store 또는 직접 배포
- **시스템 통합**: macOS Notification, Status Bar, Contacts 연동
- **백그라운드 실행**: 영상회의 최소화 시 자동 복구

---

## 2. 기술 스택 (Native macOS)

| 계층 | 기술 | 비고 |
|------|------|------|
| 언어 | Swift 5.9+ | macOS 13+ (Ventura) |
| SIP Engine | PJSIP (iOS에서 검증된 빌드) | macOS용 XCFramework |
| Media | AVFoundation + WebRTC | 카메라/마이크 |
| UI | SwiftUI + AppKit | macOS 스타일 |
| 백그라운드 | NSBackgroundActivityScheduler | 전화 수신 유지 |
| 배포 | Notarized DMG / PKG | Apple Developer 필요 |

> **참고**: PJSIP는 iOS에서 사용 시 XCFramework로 빌드해야 합니다. macOS용 동일 빌드가 가능하나 추가 검증 필요.

---

## 3. 프로젝트 구조 (Swift 패키지 기반)

```
macos-client/
├── KibalClient/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── SIPManager.swift        ← PJSIP 래퍼
│   ├── MediaManager.swift      ← AVFoundation + WebRTC
│   ├── CallManager.swift       ← 통화 상태 관리
│   ├── ConferenceManager.swift ← 회의실 관리
│   ├── UI/
│   │   ├── LoginView.swift
│   │   ├── DialerView.swift
│   │   ├── CallView.swift
│   │   └── ConferenceView.swift
│   └── Resources/
│       └── Info.plist
├── KibalClient.xcodeproj
└── Package.swift
```

---

## 4. 핵심 컴포넌트

### 4.1 SIPManager.swift (PJSIP 래퍼)

```swift
import PJSIP

class SIPManager {
    private var acc_id: pjsip_acc_id?
    private var transport_id: pjsip_transport_id?

    func register(domain: String, username: String, password: String) {
        // 1. PJSIP 엔드포인트 초기화
        // 2. TCP/TLS 또는 WebSocket 트랜스포트 생성
        // 3. 계정 등록 (REGISTER)
        // 4. 콜백 핸들러 설정 (onIncomingCall, onRegisterStatus)
    }

    func makeCall(target: String) -> pjsip_inv_session? { ... }
    func hangup(invitation: pjsip_inv_session) { ... }
}
```

### 4.2 MediaManager.swift (AVFoundation)

```swift
import AVFoundation

class MediaManager {
    private var captureSession: AVCaptureSession?
    private var localVideoTrack: AVCaptureVideoDataOutput?
    private var localAudioTrack: AVCaptureAudioDataOutput?

    func setupCaptureSession() { ... }
    func startLocalPreview(view: NSView) { ... }
    func switchCamera() { ... }
    func toggleMicrophone(enabled: Bool) { ... }
}
```

---

## 5. macOS 권한

### Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>영상통화를 위해 카메라 접근이 필요합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>영상통화를 위해 마이크 접근이 필요합니다</string>
<key>NSCalendarsUsageDescription</key>
<string>회의 일정 관리</string>
<key>SOCIAL_ACCOUNTS_USAGE_DESCRIPTION</key>
<string>연락처 동기화</string>

<key>LSMinimumSystemVersion</key>
<string>13.0</string>
```

---

## 6. 배포

### Notarized DMG 빌드 (CI/CD)

```bash
xcodebuild -project KibalClient.xcodeproj \
  -scheme KibalClient \
  -configuration Release \
  -archivePath KibalClient.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath KibalClient.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist

# Notarization
xcrun notarytool submit KibalClient.dmg \
  --apple-id "$APPLE_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --team-id "$TEAM_ID"
```

---

## 7. Web Client와 비교

| 항목 | Native macOS | Web Client |
|------|-------------|------------|
| 배포 | App Store/Direct | URL 접속 |
| 시스템 통합 | 깊음 (Notifications, Status) | 제한적 |
| 백그라운드 | 네이티브 지원 | 브라우저 제약 |
| 개발 난이도 | 높음 | 중간 |
| 유지보수 | OS별 빌드 필요 | 단일 코드베이스 |
| 라이선스 | PJSIP LGPL/GPL | SIP.js MIT |

---

## 8. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계

## 7. 개발 순서 (iOS 시뮬레이터 → Android → macOS → Windows)

| 단계 | 목표 | 완료 조건 | 시간 |
|------|------|-----------|------|
| 1 | **macOS 빌드 검증** | `flutter create macos-client`, `flutter run -d macos` 성공, 카메라 렌더링 | 1~2일 |
| 2 | **SIP 등록 테스트** | flutter_sip로 Asterisk 등록, REGISTER 성공 | 1~2일 |
| 3 | **1:1 영상통화** | 동일 네트워크에서 카메라·마이크 실시간 렌더링 | 1~2일 |
| 4 | **iOS/Xcode 검증** | iOS 시뮬레이터 16+ 에서 동일 코드로 빌드 확인 | 1~2일 |
| 5 | **Windows 빌드 검증** | `flutter create windows-client`, `flutter run -d windows` 성공 | 1~2일 |
| 6 | **TURN/STUN 구성** | coturn 설치, 외부망 ICE 후보 수집 | 1~2일 |
| 7 | **GitHub Action 배포** | CI/CD 파이프라인, `flutter build macos`/`windows` 자동 | 2~3일 |

---

## 8. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/02_Design/cross-platform-client-design]] — 크로스플랫폼 설계
- [[wiki/02_Design/iOS-client-design]] — Native iOS Client 설계
- [[wiki/05_Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정
- [[wiki/05_Decisions/ADR-003]] — iOS Native Client 결정 (Background Reception)
- [[wiki/06_Reports/macOS-client-개발보고서]] — 본 문서 리뷰 결과

---

## 9. 문서 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-10-29 | Kibal Team | 초기 설계 (참고 자료) |
| v2.0 | 2026-11-08 | TVS (Mistral Vibe) | **Flutter 기반 macOS/Windows 구현으로 변경** · 개발 단계별로 갱신 |
| v3.0 | 2026-11-12 | Claude | **0장 현행 아키텍처 추가**: sip_ua 포크, OPS 서버 설정·로그 수집, ADR-006, 빌드/발행 스크립트 |


## 5. 핵심 컴포넌트

### 5.1 SIPClient (flutter_sip)

```dart
class MacSIPClient {
  late SipClient _sipClient;

  Future<void> init() async {
    _sipClient = SipClient(
      username: sipConfig.username,
      domain: sipConfig.domain,
      password: sipConfig.password,
      transportType: SingleVideoTransportType.udp,
      port: 5060,
    );
    await _sipClient.init();
    await _sipClient.register();
  }

  Future<void> makeCall(String target) => _sipClient.call(target);
  Future<void> hangup() => _sipClient.hangup();
  void onCallReceived(Function) { ... } // CallStateListener
}
```

### 5.2 MediaManager (flutter_webrtc)

```dart
class MacMediaManager {
  late RtcConfiguration _config;
  late RtcMediaStream _localStream;

  Future<void> init() async {
    _config = RtcConfiguration(
      iceServers: [
        RtcIceServer(urlParam: 'stun:stun.l.google.com:19302'),
      ],
    );

    final mediaConstraints = MediaConstraints(
      video: TrueToken(),
      audio: TrueToken(),
    );

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  void toggleCamera() { ... }
  void toggleMicrophone() { ... }
  void onTrack(MediaStreamTrack track, String socketId) { ... }
}
```

### 5.3 macOS 메인 뷰 (TitleBar + Sidebar + Content)

```dart
class MacMainView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(36), // TitleBar 높이
        child: Container(
          height: 36,
          color: Colors.blue[800],
          child: Row(
            children: [
              // Traffic Light (red/yellow/green) — flutter_borders 또는 커스텀
              const PadPolicy(),
              const Spacer(),
              // SIP 상태, 설정, 종료 버튼
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          // Sidebar: 내선 옵션, 설정, 정보
          Container(
            width: 220,
            color: Colors.grey[200],
            child: Column(...),
          ),
          // Content: 현재 화면 (로그인/다이얼러/통화/회의)
          Expanded(
            child: Navigator(
              key: _navKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => _getScreen(settings.name!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. 기능 매트릭스

| 기능 | macOS Flutter | Windows Flutter | Mobile Flutter |
|------|--------------|-----------------|----------------|
| SIP 등록 | ✅ | ✅ | ✅ |
| 1:1 영상통화 | ✅ | ✅ | ✅ |
| 다자간 회의 | ✅ | ✅ | ✅ |
| 백그라운드 수신 (VoIP) | ⏳ 필요 | ⏳ 필요 | ✅ |
| 푸시 알림 | ⏳ 필요 | ⏳ 필요 | ✅ (APNs/FCM) |
| 카메라 전환 | ✅ | ✅ | ✅ |
| 화면 공유 | ⏳ 검토 | ⏳ 검토 | ⚠️ |
| 앱스토어/플레이스 | ❌ | ❌ (사내용) | ✅ (App Store / Play Store) |
| 즉시 업데이트 | ✅ | ✅ | ❌ |


## 3. 프로젝트 구조

```text
macos-client/                       ← 신규 디렉터리 (Web과 분리)
├── lib/
│   ├── main.dart                   ← Flutter 엔트리 포인트
│   ├── app.dart                    ← MaterialApp/Binding + 라우팅
│   └── src/
│       ├── sip/                    ← SIP 클라이언트 (Mobile과 공통)
│       │   ├── sip_client.dart
│       │   ├── sip_session.dart
│       │   └── sip_config.dart
│       ├── media/                  ← 미디어 관리 (Mobile과 공통)
│       │   ├── media_manager.dart
│       │   └── webrtc_helpers.dart
│       ├── providers/              ← 상태 관리 (Mobile과 공통)
│       │   ├── sip_provider.dart
│       │   └── media_provider.dart
│       ├── ui/                     ← macOS 전용 UI
│       │   ├── main_view.dart      ← 메인 레이아웃 (TitleBar + Sidebar + Content)
│       │   ├── login_view.dart     ← SIP 등록 화면
│       │   ├── dialer_view.dart    ← 다이얼러
│       │   ├── call_view.dart      ← 1:1 통화 화면
│       │   ├── conference_view.dart← 회의실
│       │   └── common/             ← 공통 위젯
│       └── utils/                  ← 상수, 포매터
├── macos/
│   ├── Runner/
│   │   ├── Info.plist              ← macOS 권한 선언
│   │   ├── AppDelegate.swift
│   │   └── MainMenu.xib
│   ├── Runner.xcodeproj
│   └── Flutter/
├── windows/
│   ├── Runner/
│   └── Runner.sln
├── pubspec.yaml
└── README.md
```

---

## 4. macOS 권한 (Info.plist)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSCameraUsageDescription</key>
    <string>영상통화를 위해 카메라 접근이 필요합니다.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>영상통화를 위해 마이크 접근이 필요합니다.</string>
    <key>NSScreenCaptureUsesPremiumAudio</key>
    <true/>
</dict>
</plist>
```

> **주의**: macOS는 **실시간 오디오 접근**을 위한 권한이 별도로 필요하다. `flutter_webrtc`가 `AVAudioSession`의 `playAndRecord` 카테고리를 올바르게 설정하는지에 대한 검증이 필요하다. 또한 실제 디바이스에서의 권한 다이얼로그가 뜨는지, 키오스크 모드 인가가 필요한지 확인해야 한다.



### 1.1 macOS 네이티브 앱의 필요성

| 목적 | 설명 |
|------|------|
| **고객사 요구** | 금융/증권 고객사의 상시 전화 수신, 백그라운드 전화 처리 요구 가능 |
| **시스템 통합** | macOS Notification, Status Bar, Quick Look, Spotlight, Shortcut 등 네이티브 통합 |
| **테스트 확장성** | Desktop 환경에서 실제 사용자 관점의 테스트 수행 |
| **Windows와의 페어** | Windows/macOS에서 동일한 Flutter 단일 코드베이스로 개발 |

### 1.2 기술 선택: Flutter + flutter_webrtc (기존 Mobile 재사용)

| 항목 | 선택 | 이유 |
|------|------|------|
| UI | Flutter | Mobile iOS/Android 단일 코드베이스 확장, 이미 구현 완료 |
| SIP | flutter_sip | Mobile에서 이미 검증, PJSIP bindings 재사용 |
| Media | flutter_webrtc | Mobile과 동일, 카메라/마이크/화면 공유 재사용 |
| 배포 | Windows: MSIX / macOS: DMG | 기존 Flutter toolchain으로 빌드 |
| 상태 관리 | Provider (Mobile과 동일) | 코드 재사용 |

> **참고**: 이전 설계서(v1.0)에서는 Swift/AVFoundation/PJSIP XCFramework을 제안했지만, **실제 구현은 Flutter 기반**으로 결정된다. 이는 Mobile Client와 동일한 언어를 사용해 개발·유지보수 비용을 절감하고, 웹클라이언트(Web + React)와는 기술적으로 완전히 분리한다.

---

## 2. 기술 스택 (Flutter 기반 macOS)

| 계층 | 기술 | 비고 |
|------|------|------|
| 언어 | Dart 3.x + Flutter 3.x | Mobile과 동일 SDK |
| 플랫폼 | macOS (Ventura 13+) | `flutter run -d macos` |
| SIP | flutter_sip 0.0.8 | Mobile과 동일 |
| Media | flutter_webrtc ^0.11.7 | Mobile과 동일 |
| 권한 | permission_handler | 카메라/마이크/실시간 오디오 |
| 상태 관리 | provider | Mobile과 동일 |
| UI | Custom (Flutter Widget) | macOS 스타일 (TitleBar, Sidebar 등) |
| 배포 | DMG / ZIP | Apple Notarization 불필요 (Windows/macOS 비공식) |

> **중요**: macOS에서 `flutter_webrtc`는 **Camera/ microphone access를 OS 권한으로 처리하지 않는다**. `permission_handler`로는 macOS에서 완전한 권한이 보장되지 않을 수 있다. 실제 빌드·런처로 렌더링 테스트가 필요하다.

- [[wiki/02_Design/cross-platform-client-design]] — 크로스플랫폼 설계
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정