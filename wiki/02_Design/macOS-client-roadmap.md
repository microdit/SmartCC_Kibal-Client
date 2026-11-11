# macOS Client 개발 로드맵 (Native macOS SIP Client)

| 항목 | 값 |
|------|-----|
| **작성일** | 2026-11-08 |
| **버전** | v1.1 (2026-11-12 현행화) |
| **상태** | macOS v0.0.17 — 1:1·3자 회의 성공(v0.0.16), iOS/Windows/Android 이식 대기 |
| **관련** | [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/mobile-client]], [[wiki/02_Design/cross-platform-client-design]] |

---

## 1. 목표

사용자는 **Android / iOS / macOS / Windows** 공식 네이티브 앱을 만들고자 한다.  
기존 구현된 `SmartCC_Kibal-Client`의 **Mobile Client(Flutter + flutter_sip + flutter_webrtc)**를 재사용하여 macOS와 Windows를 추가한다.

---

## 2. 단계별 실행 계획

| 단계 | 목표 | 기간 | 완료 기준 |
|------|------|------|-----------|
| **C6-A** | macOS 빌드 검증 | 1~2일 | `flutter create macos-client`, `flutter run -d macos` 성공, 카메라·마이크 렌더 확인 |
| **C6-B** | SIP 등록 확인 | 1~2일 | `flutter_sip`로 Asterisk `REGISTER` 성공, `pjsip show contacts` 확인 |
| **C6-C** | 1:1 영상통화 확인 | 1~2일 | 동일 네트워크에서 양방향 영상/음성 실시간 렌더링 |
| **C6-D** | iOS 공식 테스트 | 1~2일 | iOS 시뮬레이터 16+ 빌드, 디바이스 준비 완료 |
| **C6-E** | Windows 빌드 검증 | 1~2일 | `flutter run -d windows` 성공, 카메라·마이크 렌더 확인 |
| **C6-F** | TURN/STUN 구성 | 1~2일 | coturn 설치, 외부망 ICE 후보 수집 |
| **C6-G** | GitHub Action CI/CD | 2~3일 | `flutter build macos`/`windows` 자동, 앱 패키지 생성 |
| **C6-H** | 테스트 리포트 | 1일 | CT01~CT06 결과 리포트 작성 |

---

## 3. 개발 산출물

| 산출물 | 파일 | 상태 |
|--------|------|------|
| macOS 설계서 | `wiki/02_Design/macOS-client-design.md` | ✅ v2.0 |
| macOS UI 설계서 | `wiki/02_Design/macOS-client-ui.md` | ✅ v1.0 |
| 개발 로드맵 | `wiki/02_Design/macOS-client-roadmap.md` | ✅ v1.0 |
| 참조 설계서 | `wiki/02_Design/mobile-client.md` | ✅ |
| 참조 설계서 | `wiki/02_Design/sip-client-design.md` | ✅ |
| 참조 설계서 | `wiki/02_Design/cross-platform-client-design.md` | ✅ |
| 참조 설계서 | `wiki/02_Design/web-client.md` | ✅ |
| 참조 결정서 | `wiki/05_Decisions/ADR-002.md` | ✅ |
| 참조 결정서 | `wiki/05_Decisions/ADR-003.md` | ✅ |
| 개발 보고서 | `wiki/06_Reports/macOS-client-개발보고서.md` | 📋 작성 예정 |

---

## 4. 리스크 관리

| 리스크 | 대응 |
|--------|------|
| macOS `flutter_webrtc` 카메라 권한 미작동 | `permission_handler` + 시스템 권한 다이얼로그 별도 검증 |
| Windows 마이크/스피커 라우팅 | `AVAudioSession`별 라우팅 설정 확인 |
| Intel Mac에서 x64 지원 | Apple Silicon(i38_64) 우선, x64 테스트 별도 |
| 콜드 스타트 후 미디어 초기화 | 앱 시작 시 재권한 요청 및 미디어 재초기화 |
| PJSIP 빌드 복잡도 | Mobile에서 이미 검증된 `flutter_sip` 재사용 |

---

## 4.9 macOS 릴리스 이력 (현행)

| 버전 | 날짜 | 주요 내용 | 결과 |
|------|------|----------|------|
| v0.0.2~0.0.7 | 11-09~11 | 스캐폴/권한/UI, sip_ua 전환, 원격 오디오 H1, ICE 보정(ADR-005), 미디어 경로 H4 | DEV REGISTER/CALL/CONF OK |
| v0.0.8 | 11-11 | H5 re-INVITE 자동 수락 | 영상/다자간 ICE 실패 0 |
| v0.0.9~0.0.11 | 11-11 | 다중 영상 타일, 최신 3타일, 선택 UI | 3자 타일 안정 |
| v0.0.12~0.0.13 | 11-11 | 클라이언트 로그 OPS 자동 수집, 업로더 v2 | OPS "클라이언트 로그" |
| v0.0.14 | 11-11 | 6000 카드형 회의 UI, 수신 크래시 2건, 트랙 정리 | — |
| v0.0.15 | 11-11 | 1:1 수신 영상 판정(G1~G4), opus 우선(G6) | — |
| v0.0.16 | 11-12 | OPS 서버 설정 자동 갱신, 기본 서버 192.168.0.3, DMG 링크 결함 수정 | **1:1·3자 회의 성공** |
| v0.0.17 | 11-12 | 카메라 없는 단말 영상 recvonly(ADR-006), transceiver 진단 | 실기 검증 대기 |

### 다음 단계
1. v0.0.17 실기(1101 참가자 영상 수신) → ADR-006 확정
2. 참가자 이름(ConfBridge 참가자 API), 카메라 전환(replaceTrack)
3. Developer ID 서명·공증(Gatekeeper 경고 제거)
4. iOS/Windows/Android 이식

---

## 5. 완료 기준 (Gate)

| 항목 | 통과 기준 |
|------|-----------|
| **CT03** | Mobile SIP 등록 성공 (iOS 시뮬레이터) |
| **CT04** | Mobile 1:1 통화 성공 (iOS 시뮬레이터) |
| **CT05** | 3자 SFU 회의 성공 (Web) |
| **CT06** | 외부망/NAT 통과 (TURN 설치 후) |

---

## 6. 문서 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-11-08 | TVS (Mistral Vibe) | 최초 작성 |
| v1.1 | 2026-11-12 | Claude | 4.9 macOS 릴리스 이력·다음 단계 추가 |
