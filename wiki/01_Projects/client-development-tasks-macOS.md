# macOS Client 개발 작업계획서 (개발 작업 계획)

| 항목 | 내용 |
|------|------|
| **문서 ID** | WP-MACOS-20261108-001 |
| **프로젝트** | SmartCC_Kibal-Client (멀티플랫폼 SIP 클라이언트) |
| **작성일** | 2026-11-08 |
| **버전** | v1.0 |
| **상태** | **M1~M6 완료(2026-11-09)** — DEV 실검증 통과, 영상 실기 검증·타 플랫폼 이식 남음 |
| **관련** | [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/macOS-client-ui]], [[wiki/02_Design/macOS-client-roadmap]], [[wiki/01_Projects/client-project-plan]] |

---

## 0. 완료 현황 (2026-11-09)

| 작업 ID | 상태 | 비고 |
|---------|------|------|
| MACOS-01~03 | ✅ | 계획서/브랜치/프로젝트 스캐폴 완료 |
| MACOS-05 | ✅ | Mobile 코드 재사용 + macOS용 정비 |
| MACOS-06 | ✅ | Info.plist + entitlements 권한 구성 |
| MACOS-07 | ✅ | `MacMainView` + GoRouter 화면 동작 |
| MACOS-08 | ✅ | `tool/register_probe.dart` REGISTER_OK |
| MACOS-09 | ⚠️ 부분 | 1:1 통화·오디오 검증(CALL_OK). 영상 송출은 카메라 있는 MacBook에서 검증 예정 |
| MACOS-04 / MACOS-11 | ⬜ | Windows는 macOS 검증 후 이식 |
| MACOS-10 | ⬜ | CI/CD 미설정 |
| MACOS-12 | ✅ | `docs/보고서/20261109_macOS테스트결과보고서_v1.0.md` |

추가 완료: SIP 엔진 `sip_ua` 교체(ADR-004), ConfBridge 3자 회의 검증, 린트 0건, Release 빌드.

## 0-1. 2026-11-11 추가 진행 (원격 오디오/ICE)

| 작업 | 상태 | 비고 |
|------|------|------|
| 원격 오디오 H1(트랙 폐기) | ✅ | `sip_client.dart` 복구 로직, `recovered=true kind=audio` |
| Release UDP 엔타이틀먼트 | ✅ | `com.apple.security.network.server` |
| DTLS `certificate verify failed` | ✅ | `dtls_verify=fingerprint` |
| Docker ICE 후보 `172.19.0.2` | ⚠️ 부분 | `packages/sip_ua` 포크로 172.16/12 → `c=` 보정 (ADR-005) |
| 오디오 단독 통화 안정성 | ✅ | 1101 118초 유지(v0.0.7) |
| H5 re-INVITE 미응답 | ✅ | `onNewReinvite` 자동 수락(v0.0.8), 영상/다자간 ICE 실패 직접 원인 |
| 영상/3자 실기 재검증 | ⬜ P0 | v0.0.8로 5분 이상, `videoBytes` 증가, `Sent RTP type 100` 확인 |
| 3자 입장 시 1명 튕김 | ⬜ | H5 수정으로 해소되는지 확인 |
| v0.0.8 장시간 회귀(5분+) | ⬜ | 1:1 영상/3자 영상 |

> 상세: [[wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0]], 후속: [[wiki/04_Prompts/20261111_원격오디오_ICE_후속작업프롬프트_v1.0]]

## 1. 목표

2026-11-08 기준 `SmartCC_Kibal-Client`의 Mobile Client(Flutter + flutter_sip + flutter_webrtc)를 기반으로 다음 작업을 수행한다.

1. **macOS 네이티브 클라이언트 개발 환경 구축**
2. **Windows 클라이언트 개발 환경 구축**
3. **GitHub 브랜치 관리 및 동기화 파이프라인 구축**
4. **iOS 시뮬레이터 테스트 → Android → macOS → Windows 확장**

---

## 2. 단계별 작업 계획

| 단계 | 작업 ID | 내용 | 담당자 | 예상 시간 | 완료 기준 |
|------|---------|------|--------|-----------|-----------|
| **S1** | MACOS-01 | 작업계획서 작성 | 작성자 | 0.5일 | 본 문서 v1.0 제출 |
| **S2** | MACOS-02 | macOS 브랜치 생성 (`feature/macOS-version`) | 개발자 | 0.5일 | 브랜치 생성, 원격 push |
| **S3** | MACOS-03 | `macos-client/` 디렉터리 생성 | 개발자 | 1일 | `flutter create macos-client`, 기본 프로젝트 확인 |
| **S4** | MACOS-04 | `windows-client/` 디렉터리 생성 | 개발자 | 1일 | `flutter create windows-client`, 기본 프로젝트 확인 |
| **S5** | MACOS-05 | 기존 Mobile 코드 재사용 (lib/, providers/, sip/, media/) | 개발자 | 2일 | `macos-client/lib` ↔ `mobile/lib` 동기화 |
| **S6** | MACOS-06 | macOS 권한 설정 (Info.plist) | 개발자 | 1일 | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` |
| **S7** | MACOS-07 | macOS 메인 뷰 (TitleBar + Sidebar + Content) | 개발자 | 2일 | `MacMainView` 렌더링 성공 |
| **S8** | MACOS-08 | SIP 등록 테스트 (macOS) | 개발자 | 1일 | `REGISTER` 성공, `pjsip show contacts` 확인 |
| **S9** | MACOS-09 | 1:1 영상통화 테스트 (macOS) | 개발자 | 1일 | 동일 네트워크 양방향 영상/음성 확인 |
| **S10** | MACOS-10 | GitHub Action CI/CD 설정 | 개발자 | 2일 | `flutter build macos` 자동 성공 |
| **S11** | MACOS-11 | Windows 빌드 검증 | 개발자 | 1일 | `flutter run -d windows` 성공 |
| **S12** | MACOS-12 | 최종 테스트 리포트 | 작성자 | 0.5일 | CT01~CT06 결과 리포트 포함 |

---

## 3. Git 브랜치 전략

| 브랜치 | 용도 | 상태 |
|--------|------|------|
| `develop` | 현재 개발 브랜치 | ✅ 활성 |
| `feature/macOS-version` | **macOS 네이티브 클라이언트 개발 전용** | 신규 생성 예정 |

### 브랜치 생성 절차

```bash
# 1. develop에서 최신화
git checkout develop
git pull origin develop

# 2. 새 브랜치 생성
git checkout -b feature/macOS-version

# 3. 작업 후 커밋
git add -A
git commit -m "feat: macOS/Windows 네이티브 클라이언트 개발 준비

- macos-client/ 디렉터리 생성
- windows-client/ 디렉터리 생성
- 모바일 코드 재사용 (SIP/media/provider)
- macOS 권한 설정 및 메인 뷰 추가
- 작업계획서 작성"

# 4. 원격 푸시
git push -u origin feature/macOS-version

# 5. 동기화
./scripts/git-sync.sh --auto --no-deploy
```

---

## 4. 위클리 진행 계획

| 주차 | 목표 | 주요 산출물 |
|------|------|-------------|
| **1주차** | 개발 환경 구축 (S2~S5) | `macos-client/`, `windows-client/`, 기본 코드 재사용 |
| **2주차** | 기능 구현 (S6~S9) | macOS 권한, SIP 등록, 1:1 영상통화 확인 |
| **3주차** | 테스트 및 배포 (S10~S12) | CI/CD, 테스트 리포트, 결과 문서화 |

---

## 5. 커밋 규칙

| 타입 | 설명 |
|------|------|
| `feat` | macOS/Windows 클라이언트 주요 기능 |
| `fix` | 버그 수정 |
| `docs` | 위키 문서, 작업계획서 갱신 |
| `chore` | 빌드 도구, 의존성, 환경 설정 |
| `test` | 단위/통합 테스트 추가 |

---

## 6. 동기화 및 배포

| 단계 | 명령어 | 설명 |
|------|--------|------|
| **로컬 커밋** | `git add -A && git commit -m "..."` | 변경 사항 커밋 |
| **원격 push** | `git push -u origin feature/macOS-version` | GitHub에 push |
| **3-Way 동기화** | `./scripts/git-sync.sh --auto --no-deploy` | dev/prd 동기화 |
| **배포** | `./scripts/git-sync.sh --auto --deploy` | PRD 배포 |

---

## 7. 완료 기준 (Gate)

| 테스트 | 통과 기준 |
|--------|-----------|
| **CT01** | SIP 등록 성공 (macOS) |
| **CT02** | 1:1 통화 성공 (macOS) |
| **CT05** | 3자 SFU 회의 성공 (macOS + Web) |
| **CT06** | 외부망/NAT 통과 (TURN 설치 후) |

---

## 8. 관련 문서

- [[wiki/02_Design/macOS-client-design]] — macOS 설계서
- [[wiki/02_Design/macOS-client-ui]] — UI 설계서
- [[wiki/02_Design/macOS-client-roadmap]] — 개발 로드맵
- [[wiki/01_Projects/client-project-plan]] — 프로젝트 계획
- [[wiki/06_Reports/macOS-client-개발보고서]] — 개발 보고서

---

## 9. 문서 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-11-08 | TVS (Mistral Vibe) | 최초 작성 |
