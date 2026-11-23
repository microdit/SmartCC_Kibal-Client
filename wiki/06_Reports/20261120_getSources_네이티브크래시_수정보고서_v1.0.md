# getSources 네이티브 크래시 수정 보고서

| 항목 | 내용 |
|------|------|
| **작성일** | 2026-11-20 |
| **버전** | v1.0 |
| **증상** | v0.0.43에서 영상 품질 수동 적용 직후 앱 SIGSEGV |
| **증거** | `docs/테스트/v0.0.43/1102죽음.txt` |
| **수정 버전** | `v0.0.46` (SHA256 `8edacb7a…`) |

---

## 1. 원인

`flutter_webrtc`의 `getSources:`가 `dispatch_get_global_queue(QOS_CLASS_USER_INITIATED)`에서 `AVCaptureDevice`를 열거했다. macOS 26에서 `AVCaptureDevice`의 `+initialize`/메서드 스위즐링(`avc_transferMethod`, `TundraPersonality`)이 백그라운드 큐에서 동시에 일어나 `doesNotRecognizeSelector` → `EXC_BAD_ACCESS`가 발생했다.

크래시 지점:
`FlutterRTCMediaStream.m:696` — `device.positionString` 접근.

---

## 2. 수정

로컬 포크의 3개 파일에서 `getSources:` 디스패치를 메인 큐로 변경:

- `macos/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCMediaStream.m`
- `ios/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCMediaStream.m`
- `common/darwin/Classes/FlutterRTCMediaStream.m`

```objc
dispatch_async(dispatch_get_main_queue(), ^{ ... });
```

최초 카메라 탐색 시 최대 약 1초 UI 지연이 있을 수 있으나, 네이티브 크래시보다 안전한 동작을 선택했다.

---

## 3. 검증

| 항목 | 결과 |
|------|------|
| `flutter analyze` | No issues found |
| `flutter test` | 17/17 passed |
| 빌드 | `v0.0.46` 발행 |

---

## 4. 잔여

- v0.0.46 설치 후 수동 품질 적용(720p→1080p→4K) 반복 테스트 필요.
- iOS 실기기에서 동일 경로 확인 필요.

---

## 5. 관련 문서

- [[wiki/07_Logs/20261120]]
- [[wiki/08_Experiments/20261120_클라이언트품질진단_자체검증_v1.0]]
