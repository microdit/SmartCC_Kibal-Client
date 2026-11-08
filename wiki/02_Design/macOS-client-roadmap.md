# macOS Client 개발 로드맵 (Native macOS SIP Client)

| 항목 | 값 |
|------|-----|
| **작성일** | 2026-11-08 |
| **버전** | v1.0 |
| **상태** | 진행 중 — Stage C6 준비 (Android/iOS/macOS/Windows 동시 확장) |
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
