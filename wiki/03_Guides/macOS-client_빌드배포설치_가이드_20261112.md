# macOS Client 빌드·발행·설치 가이드

**날짜**: 2026-11-12
**버전**: v1.0
**대상**: 개발자/운영자 (MacPro 1101, MacBook 1102, iMac 1103)
**관련**: `macos-client/scripts/build_macos.sh`, `macos-client/scripts/release_macos.sh`, 서버 리포 `wiki/03_Guides/서버IP변경_자동갱신_가이드_20261111.md`, `OPS_Asterisk_점검스크립트_사용설명서_20261112.md`

---

## 1. 스크립트

| 스크립트 | 용도 |
|----------|------|
| `scripts/build_macos.sh [debug\|release] [--no-dmg]` | pubspec 버전으로 앱 빌드 + DMG 생성(빌드만) |
| `scripts/release_macos.sh [patch\|minor\|major\|X.Y.Z\|--no-bump] [--skip-tests] [--install] [--commit]` | 버전 증가 → analyze/test → 빌드+DMG → 산출물 점검 → sha256 → (설치/커밋·태그) |

`release_macos.sh`가 내부에서 `build_macos.sh`를 호출한다. **버전 발행은 항상 `release_macos.sh`**.

## 2. 버전 발행 (MacPro)

```bash
cd ~/Downloads/dev/SmartCC_Kibal-Client/macos-client
./scripts/release_macos.sh            # 0.0.17 → 0.0.18
cd .. && ./scripts/git-sync.sh "release(macos): v0.0.18" --no-deploy
```

산출물: `build/macos/Build/Products/Release/macos_client_vX.Y.Z.dmg` + `.dmg.sha256`

점검 항목(스크립트 6단계): Info.plist 버전, `x86_64 arm64`, codesign 검증, DMG의 `Applications` **바로가기(링크)**, DMG 내부 앱 버전.

## 3. 다른 Mac에서 직접 빌드 (권장 — Gatekeeper 경고 없음)

```bash
cd ~/Downloads/dev/SmartCC_Kibal-Client && git pull
cd macos-client && ./scripts/release_macos.sh --no-bump --install
'open /Applications/macos_client.app'
open /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/macos-client/build/macos/Build/Products/Release/macos_client.app


```

사전: Flutter, Xcode, CocoaPods (`flutter doctor`).

## 4. DMG 복사 설치

```bash
xattr -d com.apple.quarantine ~/Downloads/macos_client_vX.Y.Z.dmg   # 격리 표시 제거
open ~/Downloads/macos_client_vX.Y.Z.dmg                            # 앱 → Applications 끌어다 놓기
xattr -dr com.apple.quarantine /Applications/macos_client.app
open /Applications/macos_client.app
```

> "Apple은 'macos_client'에 악성 코드가 없음을 확인할 수 없습니다" = **빌드 이상 아님.** ad-hoc 서명 앱 + 전송 시 붙은 `com.apple.quarantine` 때문. 근본 해결은 Developer ID 서명·공증.

## 5. 첫 실행 확인

1. 로그인 화면 상단: "서버 주소 갱신됨: 192.168.0.3" 또는 "서버 설정 최신"
2. 실패 시 "서버 설정 갱신" 버튼 → 그래도 실패면 도메인 `192.168.0.3`, WS `ws://192.168.0.3:8088/ws` 직접 입력
3. **내선 중복 로그인 금지**: MacPro=1101, MacBook=1102, iMac=1103
4. MacPro에서 확인:
   ```bash
   ./scripts/ops_client_logs.sh list      # app=vX.Y.Z, last=수초
   cd ../SmartCC_Kibal && ./server/scripts/verify.sh   # 내선 Avail
   ```

## 6. 문제 해결

| 증상 | 원인 | 조치 |
|------|------|------|
| Gatekeeper 경고 | quarantine | 4장 `xattr` 또는 3장 직접 빌드 |
| `/Applications/macos_client.app` 없음 | DMG에서 직접 실행/설치 안 함 (v0.0.16 이전 DMG는 Applications 링크 결함) | 최신 DMG로 끌어다 놓기 또는 `--install` |
| 서버 설정 갱신 실패 | 단말이 서버와 다른 대역 | `curl http://192.168.0.3:8091/health` → 200 확인 |
| 로그가 다른 내선에 섞임 | 같은 내선 중복 로그인 | 각자 내선으로 재로그인 |
