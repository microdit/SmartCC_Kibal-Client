# Kibal macOS Client

Asterisk 22 LTS(`SmartCC_Kibal`)와 연동하는 macOS 네이티브 SIP 영상통화 클라이언트입니다.

## 기술 스택

| 구분 | 내용 |
|------|------|
| 프레임워크 | Flutter 3.47 (macOS desktop) |
| SIP | `sip_ua` (dart-sip-ua) — WebSocket 시그널링 |
| 미디어 | `flutter_webrtc` — 네이티브 WebRTC (DTLS-SRTP) |
| 상태 관리 | Provider |
| 라우팅 | GoRouter |

브라우저가 아니므로 **HTTPS / WSS 인증서가 필요 없으며**, 카메라·마이크는 macOS 권한(`Info.plist`, entitlements)으로 처리합니다. 카메라가 없는 기기에서는 자동으로 음성 통화로 대첩니다.

## 실행

```bash
flutter pub get
flutter run -d macos
```

CocoaPods가 필요한 경우 `pod`이 PATH에 있어야 합니다.

## DEV 서버

- 기본 서버: `192.168.11.39` (Docker `kibal-dev-asterisk`)
- WebSocket: `ws://192.168.11.39:8088/ws`
- 테스트 내선: `1101`~`1104` (비밀번호 `<내선>pass`)
- 회의실(ConfBridge): `6000`

기본값은 `lib/src/utils/constants.dart`에서 변경합니다.

## 검증 도구 (`tool/`)

```bash
# REGISTER 스모크 테스트
flutter run -d macos --debug -t tool/register_probe.dart \
  --dart-define=SIP_USERNAME=1102 --dart-define=SIP_PASSWORD=1102pass
# 기대: >>> RESULT: REGISTER_OK

# 1:1 통화 (1102 → 1103, 자동 수신)
flutter run -d macos --debug -t tool/call_probe.dart
# 기대: >>> RESULT: CALL_OK

# 3자 회의 (1102/1103/1104 → 6000)
flutter run -d macos --debug -t tool/conference_probe.dart
# 기대: >>> RESULT: CONFERENCE_OK
```

## 빌드

```bash
flutter build macos --debug
flutter build macos --release   # 서명/공증은 별도 설정 필요
```

## 테스트

```bash
flutter test
flutter analyze
```
