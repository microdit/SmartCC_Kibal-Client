# iOS Client 설계 (Native iOS SIP Client)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 참고 자료 (향후 네이티브 앱 필요 시) |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/mobile-client]], [[wiki/05/Decisions/ADR-003]] |

---

## 1. 설계 배경

Web Client(Mobile Safari)로 시작하나, **iOS 백그라운드에서의 상시 전화 수신**은 다음과 같은 제약이 있어 네이티브 iOS 앱 필요성이 있습니다.

| 제약 | Mobile Safari PWA | Native iOS App |
|------|-------------------|---------------|
| 백그라운드 WebRTC | ❌ (5초 제한) | ✅ (VoIP background mode) |
| 푸시 알림 | ❌ | ✅ (APNs) |
| 카메라 전환 | 제한적 | ✅ (완전 제어) |
| App Store | ❌ | ✅ |

iOS에서의 백그라운드 전화 수신은 **VoIP (Voice over IP) Background Mode**가 필수입니다.

---

## 2. 기술 스택 (Native iOS)

| 계층 | 기술 | 비고 |
|------|------|------|
| 언어 | Swift 5.9+ | iOS 15+ (SwiftUI) |
| SIP Engine | PJSIP (iOS XCFramework) | 검증된 빌드 |
| Media | AVFoundation | 카메라/마이크 |
| Video Rendering | OpenGL/ES 또는 Metal | 실시간 렌더링 |
| 상태 관리 | Combine + ObservableObject | SwiftUI와 연동 |
| 백그라운드 | PushKit (VoIP) | 백그라운드 전화 수신 |
| 배포 | App Store | Apple Developer 필요 |

---

## 3. 프로젝트 구조

```
ios-client/
├── KibalClient/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── CallManager.swift        ← CallKit 연동
│   ├── SIPManager.swift         ← PJSIP 래퍼
│   ├── MediaManager.swift       ← AVFoundation
│   ├── ConferenceManager.swift  ← 회의실 관리
│   ├── IncomingCallViewController.swift ← 부팅 화면
│   ├── UI/
│   │   ├── LoginView.swift
│   │   ├── DialerView.swift
│   │   ├── CallView.swift
│   │   └── ConferenceView.swift
│   └── Resources/
│       └── Info.plist
├── KibalClient.xcodeproj
└── Podfile (PJSIP)
```

---

## 4. 핵심 기능

### 4.1 VoIP Background (PushKit)

```swift
import PushKit

class CallManager: NSObject, PKPushRegistryDelegate {
    func configureVoIP() {
        let registry = PKPushRegistry(queue: nil)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }

    // 백그라운드 전화 수신
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceivePushWith payload: PKPushPayload,
        callUUID: UUID,
        completion: @escaping () -> Void
    ) {
        let sipUri = payload.dictionaryPayload["sip_uri"] as? String
        // App 보고/잠자 모드에서도 실행됨
        startIncomingCall(sipUri: sipUri)
        completion()
    }
}
```

### 4.2 SIPManager.swift (PJSIP)

```swift
import PJSIP

class SIPManager {
    private var acc_id: pjsip_acc_id?

    func register(
        domain: String,
        username: String,
        password: String,
        onRegisterSuccess: @escaping () -> Void,
        onIncomingCall: @escaping (pjsip_uri) -> Void
    ) {
        // PJSIP Endpoint 초기화
        // SIP 계정 등록 (REGISTER)
        // 콜백: on_reg_state, on_incoming_call
    }

    func makeCall(target: String) -> pjsip_inv_session? { ... }
    func acceptCall(invitation: pjsip_inv_session) { ... }
    func hangup(invitation: pjsip_inv_session) { ... }
}
```

### 4.3 AVAudioSession (오디오 라우팅)

```swift
import AVFoundation

func configureAudioSession() {
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
    try? audioSession.setActive(true)
}

// 블루투스/이어폰/스피커 전환
func setAudioOutputPort(port: AVAudioSession.PortOverride) {
    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(port)
}
```

---

## 5. iOS 권한 (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>영상통화를 위해 카메라 접근이 필요합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>영상통화를 위해 마이크 접근이 필요합니다</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
    <string>fetch</string>
    <string>processing</string>
</array>

<key>LSMinimumSystemVersion</key>
<string>15.0</string>
```

---

## 6. App Store 배포

```bash
# Archive
xcodebuild -project KibalClient.xcodeproj \
  -scheme KibalClient \
  -configuration Release \
  -archivePath KibalClient.xcarchive \
  archive

# Export
xcodebuild -exportArchive \
  -archivePath KibalClient.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

---

## 7. VoIP 라이선스

iOS VoIP Background Mode는 Apple 심사에서 다음을 요구할 수 있습니다.

- 실제 전화 기능을 제공해야 함
- VoIP 외 다른 용도로 사용 불가
- 사용자가 기능을 명확히 인지해야 함

---

## 8. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/02_Design/mobile-client]] — Flutter Mobile Client
- [[wiki/05/Decisions/ADR-003]] — iOS Native Client 결정 (Background Reception)