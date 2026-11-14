# GUIDE-20261115-V0028-REL-001: release_macos.sh analyze 실패 — packages/**/example 제외

- **대상**: `macos-client` v0.0.28+28, `./scripts/release_macos.sh`
- **증상**: `[4] flutter analyze / test` 단계에서 `analyze 실패` 종료. 에러 26건이 전부 `packages/flutter_webrtc/example/` 하위(`flutter_background` 미해결 import, `flutter_webrtc_example` 미존재 등) + `analysis_options.yaml` pedantic include 불가.
- **원인**: `flutter analyze`가 로컬 포크(`packages/flutter_webrtc`, `packages/sip_ua`)의 example 앱까지 분석. example은 배포 앱과 무관하며 의존성(`flutter_background` 등)이 pubspec에 없어 항상 실패.
- **조치**: `macos-client/analysis_options.yaml`의 `analyzer.exclude`에 `packages/**/example/**` 추가.
- **검증**: `flutter analyze` → info 2건(기존 `login_screen.dart:474`, `ops_directory.dart:37`)만 남고 통과. `build_macos.sh release`는 원래 문제없이 성공(analyze 단계 없음)했으나 release_macos.sh도 이제 통과.
- **재발 방지**: 로컬 포크/vendored 패키지의 example·test 디렉토리는 분석 대상에서 제외할 것. 포크 업데이트 시에도 exclude 유지.
- **비고**: CocoaPods 경고(플러그인 전부 Swift Package인데 Podfile 잔존)는 별개 경고로 빌드에 영향 없음. `try?` 불필요 경고(`AppDelegate.swift:206`)도 무해.
