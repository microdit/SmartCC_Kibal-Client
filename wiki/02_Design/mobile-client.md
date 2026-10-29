# Mobile Client 설계 (Flutter + flutter_webrtc)

| 항목 | 값 |
|------|---|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 계획 중 |
| **관련** | [[wiki/02_Design/sip-client-design]], [[wiki/02_Design/web-client]], [[wiki/05/Decisions/ADR-002]] |

---

## 1. 설계 배경

`멀티플랫폼-SIP-clients.md` 평가에서 **Flutter + flutter_webrtc** 기반 모바일 클라이언트는 다음을 위해 유지보수 검토 대상입니다.

### 1.1 Flutter + flutter_webrtc 장점

| 항목 | 이유 |
|------|------|
| **단일 코드베이스** | iOS + Android 동시 개발 |
| **네이티브 API 접근** | 카메라, 마이크, 푸시 알림 |
| **백그라운드 수신** | iOS/Android 네이티브 백그라운드 SIP 처리 가능 |
| **앱스토어 배포** | 독립 앱으로 서비스 가능 |

### 1.2 Web Client와의 비교

| 항목 | Web Client | Mobile Client |
|------|-----------|---------------|
| 배포 | URL 접속 | 앱스토어 설치 |
| 백그라운드 | 브라우저 제약 | 네이티브 지원 |
| 푸시 알림 | 불가 | 가능 (APNs / FCM) |
| 카메라 접근 | 제한적 | 네이티브 API |
| 업데이트 | 즉시 | 앱스토어 검토 필요 |
| 개발 난이도 | 낮음 | 중간 |

---

## 2. 프로젝트 구조

```
mobile/
├── lib/
│   ├── main.dart                    ← Flutter 엔트리 포인트
│   ├── app.dart                     ← MaterialApp 라우팅
│   ├── src/
│   │   ├── sip/
│   │   │   ├── sip_client.dart     ← SIP 등록/발신/수신
│   │   │   ├── sip_session.dart    ← 세션 관리
│   │   │   └── conference_manager.dart ← 회의실 참여
│   │   ├── media/
│   │   │   ├── media_manager.dart  ← flutter_webrtc 래퍼
│   │   │   └── webrtc_helpers.dart ← 헬퍼 함수
│   │   ├── ui/
│   │   │   ├── login/              ← 로그인/SIP 등록 화면
│   │   │   ├── dialer/             ← 다이얼러
│   │   │   ├── call/               ← 1:1 영상통화
│   │   │   └── conference/         ← 회의실
│   │   ├── providers/
│   │   │   ├── sip_provider.dart   ← 상태 관리 (Provider)
│   │   │   └── media_provider.dart ← 미디어 상태
│   │   └── utils/
│   │       ├── constants.dart      ← SIP 도메인/포트 상수
│   │       └── formatters.dart     ← 포맷 유틸
│   ├── l10n/                        ← 다국어 (한국어/영어)
│   └── theme/                       ← 앱 테마
├── android/                         ← Android 네이티브
├── ios/                             ← iOS 네이티브
├── pubspec.yaml                     ← Flutter 의존성
├── Dockerfile                       ← (선택) 빌드용
└── README.md
```

---

## 3. 핵심 라이브러리

| 라이브러리 | 용도 | 버전 |
|-----------|------|------|
| flutter_webrtc | WebRTC (카메라/마이크/media) | 0.11+ |
| flutter_sip | SIP User Agent (PJSIP 래퍼) | 0.0.7+ |
| provider | 상태 관리 | 6.1+ |
| go_router | 라우팅 | 15+ |
| permission_handler | 권한 요청 | 11+ |
| firebase_messaging | 푸시 알림 (선택) | 15+ |

### 3.1 flutter_webrtc 사용 예시

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaManager {
  late MediaStream _localStream;
  final Map<String, MediaStream> _remoteStreams = {};

  Future<MediaStream> getUserMedia() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    return _localStream;
  }

  void onTrack(MediaStreamTrack track, String socketId) {
    if (track.kind == 'video') {
      _remoteStreams[socketId] = MediaStream()..addTrack(track);
    }
  }
}
```

### 3.2 flutter_sip 사용 예시

```dart
import 'package:flutter_sip/flutter_sip.dart';

class SipClient {
  late SIPClient _client;

  Future<void> init() async {
    _client = SIPClient();
    await _client.init(SIPSettings(
      username: '1001',
      domain: '192.168.11.2',
      password: 'secret',
      transportType: SingleVideoTransportType.udp,
      port: 5060,
    ));
    await _client.register();
  }

  Future<void> makeCall(String target) => _client.call(target);
  Future<void> hangup() => _client.hangup();
}
```

---

## 4. iOS 권한 설정

### 4.1 Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>영상통화를 위해 카메라 접근이 필요합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>영상통화를 위해 마이크 접근이 필요합니다</string>
<key>NSSiriUsageDescription</key>
<string>통화 음성 인식</string>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
  <string>fetch</string>
</array>
```

### 4.2 Android 권한 (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

---

## 5. 빌드 및 배포

### 5.1 개발

```bash
cd mobile/
flutter pub get
flutter run
```

### 5.2 Android 릴리즈 빌드

```bash
flutter build appbundle --release  # Play Store 배포용
```

### 5.3 iOS 릴리즈 빌드

```bash
flutter build ios --release --no-codesign
# Xcode에서 signing 및 App Store 배포
```

---

## 6. 관련 문서

- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 전체 설계
- [[wiki/02_Design/web-client]] — Web Client (React + SIP.js)
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 아키텍처 결정
- [[wiki/03_Guides/development-guide]] — 클라이언트 개발 가이드