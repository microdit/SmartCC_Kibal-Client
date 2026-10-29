# macOS Client 설계 (Native macOS SIP Client)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 참고 자료 (향후 네이티브 앱 필요 시) |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/cross-platform-client-design]] |

---

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
- [[wiki/02_Design/cross-platform-client-design]] — 크로스플랫폼 설계
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정