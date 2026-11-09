# MacBook AI Agent 후속 작업 프롬프트 (macOS Client)

> 이 문서를 MacBook의 AI agent에게 그대로 전달하면 됩니다.
> 목적: Intel Mac에서 완료된 macOS 클라이언트를 MacBook으로 가져와 **영상 포함 실기 검증과 남은 작업**을 수행합니다.

---

## 0. 현재 상태 요약 (2026-11-09 기준)

- 리포지토리: `git@github.com:microdit/SmartCC_Kibal-Client.git`
- 브랜치: **`feature/macOS-version`**
- 대상 앱: **`macos-client/`** (Flutter macOS desktop)
- 완료: macOS 스캐폴, 컴파일 클린, SIP 엔진을 `sip_ua`로 교체, DEV Asterisk 대상 **REGISTER / 1:1 통화 / 3자 회의(ConfBridge 6000) 자동 검증 PASS**, 린트 0건, Debug/Release 빌드 성공
- 제약: 작업한 Intel Mac에는 **카메라가 없어 영상 송출은 미검증**(음성으로 검증). MacBook에서 영상 검증이 필요합니다.

## 1. 가져오기 및 빌드

```bash
git clone git@github.com:microdit/SmartCC_Kibal-Client.git
cd SmartCC_Kibal-Client
git checkout feature/macOS-version
cd macos-client
flutter pub get
flutter analyze          # 기대: No issues found!
flutter test             # 기대: All tests passed!
flutter build macos --debug
flutter run -d macos
```

주의사항:
- CocoaPods가 필요하면 `pod --version` 확인. 없으면 `brew install cocoapods`(또는 `sudo gem install cocoapods`). Flutter가 “모든 플러그인이 Swift Package”라고 안내하는 경우 Pod 관련 경고는 무시 가능합니다.
- 최초 실행 시 macOS가 **카메라/마이크 권한**을 물으면 허용하세요. 권한은 `macos/Runner/Info.plist`와 entitlements에 이미 설정되어 있습니다.
- 앱이 백그라운드에서 실행 중이면 종료 후 다시 실행하세요.

## 2. DEV 서버 연결 확인

- DEV Asterisk: `192.168.11.39` (작업용 Intel Mac의 Docker `kibal-dev-asterisk`). MacBook은 **같은 네트워크**에 있어야 합니다.
- 확인: `nc -z 192.168.11.39 8088` 성공해야 합니다. 서버가 꺼져 있으면 Intel Mac에서 `docker start kibal-dev-asterisk`.
- 앱 기본 서버는 이미 DEV로 설정되어 있습니다(`lib/src/utils/constants.dart`). 테스트 계정: 내선 `1101`~`1104`, 비밀번호 `<내선>pass`. 회의실: `6000`.

## 3. 자동 검증(회귀)

```bash
cd macos-client

# 1) REGISTER
flutter run -d macos --debug -t tool/register_probe.dart \
  --dart-define=SIP_USERNAME=1102 --dart-define=SIP_PASSWORD=1102pass
# 기대: >>> RESULT: REGISTER_OK

# 2) 1:1 통화 (1102→1103, 자동 수신)
flutter run -d macos --debug -t tool/call_probe.dart
# 기대: >>> RESULT: CALL_OK

# 3) 3자 회의 (1102/1103/1104→6000)
flutter run -d macos --debug -t tool/conference_probe.dart
# 기대: >>> RESULT: CONFERENCE_OK
```

**MacBook에서는 카메라가 있으므로** `REMOTE STREAM video=1`이 나오는지 확인하세요. Intel Mac에서는 `video=0 audio=1`이었습니다. 영상 스트림이 1 이상이면 송수신 경로가 실제로 동작하는 것입니다.

## 4. 수동 UI 시나리오 (필수)

1. 로그인: 내선 `1102` / `1102pass`, 서버 `192.168.11.39`, WS `ws://192.168.11.39:8088/ws` → **등록됨** 표시 확인
2. 다이얼러에서 `1101`(웹 클라이언트) 또는 `1103`으로 발신 → **상대방 영상이 메인 화면에 표시**, 내 영상 PIP 확인
3. 음소거/카메라 끄기 토글 동작 확인, 종료 버튼으로 다이얼러 복귀
4. 반대로 **다른 클라이언트가 1102로 전화** → 수신 다이얼로그 → 수락 시 영상 통화 연결, 거부 시 정상 종료
5. 회의실 탭에서 `6000` 참가 → 2명 이상 접속 시 그리드에 회의 영상 표시, 회의 종료 동작 확인

상대방이 필요하면 웹 클라이언트를 사용하세요:
```bash
cd web && npm run dev   # http://localhost:5173 (웹은 localhost라 HTTPS 없이 카메라 사용 가능)
# 내선 1101 / 1101pass 로 로그인
```

## 5. 남은 작업과 수행 방법

| 순서 | 작업 | 방법 |
|------|------|------|
| 1 | 영상 송수신 검증 | 위 3·4번 수행. `video=1` 및 실제 화면 표시 확인. 실패 시 `flutter run` 콘솔의 `getusermediafailed`, SDP/코덱 오류 로그 수집 |
| 2 | 발견된 UI/미디어 결함 수정 | 원격 렌더러는 `MediaManager.addRemoteStream`에서 `srcObject` 연결. 스트림 이벤트는 `SipProvider.drainMediaEvents()` → `CallScreen`/`ConferenceView`로 전달되는 구조 |
| 3 | 결과 문서화 | `docs/보고서/20261109_macOS테스트결과보고서_v1.0.md`의 CT-M07/M08에 영상 결과를 추가하고, `wiki/07_Logs/`에 작업로그 추가 |
| 4 | Release 패키징 | `flutter build macos --release`. 배포가 필요하면 Xcode에서 Signing Team 설정(Apple Developer 계정 필요), 공증은 별도 진행 |
| 5 | Wiki 벡터 DB 색인 | 저장소 루트에서 `venv_kibal/bin/python scripts/index_wiki.py --reindex` |
| 6 | 커밋·푸시 | `./scripts/git-sync.sh --auto` (github/dev/prd 3-way) |

## 6. 참고 문서

- 계획: `docs/보고서/20261109_macOS작업계획서_v1.0.md`
- 테스트 결과: `docs/보고서/20261109_macOS테스트결과보고서_v1.0.md`
- 개발 보고: `wiki/06_Reports/20261109_macOS_M1-M6_개발완료보고서.md`
- 기술 결정: `wiki/05_Decisions/ADR-004.md` (왜 `flutter_sip`가 아니라 `sip_ua`인가)
- 사용법: `macos-client/README.md`

## 7. 하지 말아야 할 것

- `flutter_sip`를 다시 추가하지 마세요(Android 전용, iOS/macOS에서 `MissingPluginException` 발생).
- SIP 전송을 UDP로 바꾸지 마세요. `sip_ua`는 WS/TCP만 지원합니다.
- PRD(`192.168.11.2`)로 기본값을 바꾸지 마세요. 현재 검증 환경은 DEV(`192.168.11.39`)입니다.
- `macos/Flutter/ephemeral/`, `build/`, `.dart_tool/`은 커밋하지 마세요.
