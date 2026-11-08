# macOS Client 개발 보고서 (Native macOS SIP Client)

| 항목 | 내용 |
|------|------|
| **문서 ID** | MR-20261108-Mac-001 |
| **프로젝트** | SmartCC_Kibal-Client (멀티플랫폼 SIP 클라이언트) |
| **작성일** | 2026-11-08 |
| **버전** | v1.0 |
| **상태** | 작성 완료 |
| **대상** | macOS 네이티브 클라이언트 개발 (Flutter 기반) |
| **관련** | [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/macOS-client-ui]], [[wiki/02_Design/macOS-client-roadmap]] |

---

## 1. 개요

2026-11-08 기준, `SmartCC_Kibal-Client`의 Mobile Client(Flutter + flutter_sip + flutter_webrtc)는 구현 완료 상태다. iOS는 시뮬레이터에서 동작 확인 완료했으며, 사용자는 **Android / iOS / macOS / Windows** 공식 빌드를 만들어 테스트하려고 한다.

본 보고서는 **macOS 네이티브 클라이언트 개발**을 위한 설계 문서, UI 설계서, 개발 로드맵을 정리하고 현재 진행 상태를 보고한다.

---

## 2. 현재 상태 요약

| 구분 | 상태 | 근거 |
|------|------|------|
| **Web 클라이언트** | ✅ 완료 | React + SIP.js + WebRTC, CT01~CT05 DEV/PRD PASS |
| **Mobile 클라이언트 (iOS/Android)** | ✅ 구현 완료 | 14개 Dart 파일, 4,500+ 라인 |
| **iOS 시뮬레이터 테스트** | ✅ 완료 (사용자 확인) | iOS 빌드 성공, 시뮬레이터 동작 확인 |
| **Android** | ⏳ 미빌드 | `mobile/android/` 코드 존재, 빌드 미확인 |
| **Windows** | ⏳ 미시작 | Flutter Windows 프로젝트 미생성 |
| **macOS** | ⏳ 미시작 | Flutter macOS 프로젝트 미생성 |
| **TURN/STUN** | ⏳ 미구성 | coturn 미설치, CT06 BLOCKED |
| **WSS/TURN 인프라** | ⏳ 미구성 | 외부망 테스트 대비 필요 |

---

## 3. 문서 등록 내역

| 파일 | 역할 | 버전 | 상태 |
|------|------|------|------|
| `wiki/02_Design/macOS-client-design.md` | macOS 설계서 (Flutter 기반) | v2.0 | ✅ 갱신 완료 |
| `wiki/02_Design/macOS-client-ui.md` | macOS UI 설계서 | v1.0 | ✅ 신규 작성 |
| `wiki/02_Design/macOS-client-roadmap.md` | macOS 개발 로드맵 | v1.0 | ✅ 신규 작성 |
| `wiki/06_Reports/macOS-client-개발보고서.md` | 본 보고서 | v1.0 | ✅ 신규 작성 |
| `wiki/02_Design/mobile-client.md` | Mobile Client 설계 | v1.0 | 참조 유지 |
| `wiki/02_Design/sip-client-design.md` | SIP 클라이언트 설계 | v1.1 | 참조 유지 |
| `wiki/02_Design/cross-platform-client-design.md` | 크로스플랫폼 설계 | v1.0 | 참조 유지 |
| `wiki/05_Decisions/ADR-002.md` | 웹RTC+SIP.js 아키텍처 결정 | v1.0 | 참조 유지 |
| `wiki/05_Decisions/ADR-003.md` | iOS Native Client 결정 | v1.0 | 참조 유지 |

---

## 4. 다음 작업 (우선순위순)

| 우선순위 | 작업 | 예상 시간 | 완료 기준 |
|----------|------|-----------|-----------|
| **P0** | `flutter create macos-client` 및 macOS 빌드 | 1~2일 | `flutter run -d macos` 성공, 카메라·마이크 렌더링 확인 |
| **P0** | Linux/Windows 빌드 환경 준비 | 1일 | `flutter create windows-client`, 컴파일 성공 |
| **P1** | SIP 등록 테스트 (macOS) | 1일 | `REGISTER` 성공, `pjsip show contacts` 확인 |
| **P1** | 1:1 통화 테스트 (macOS) | 1일 | 동일 네트워크 양방향 영상/음성 확인 |
| **P2** | iOS 공식 디바이스 테스트 | 1일 | 시뮬레이터와 디바이스 간 카메라/마이크 일치 확인 |
| **P2** | TURN/STUN 구성 | 1~2일 | coturn 설치, 외부망 ICE 후보 수집 |
| **P2** | iOS/Android 빌드 자동화 | 2~3일 | GitHub Action으로 `flutter build` 성공 |

---

## 5. 기대 효과

| 효과 | 설명 |
|------|------|
| **플랫폼 확장** | 기존 Mobile 코드를 그대로 재사용하여 macOS/Windows 추가 |
| **개발 효율** | 단일 Dart 코드베이스로 4개 플랫폼 지원 |
| **테스트 용이성** | Desktop 화면에서 사용자 관점의 실제 테스트 가능 |
| **고객사 요구 대응** | 금융/증권 고객사의 네이티브 앱 요구 대응 |

---

## 6. 리스크

| 리스크 | 설명 | 대응 |
|--------|------|------|
| macOS 카메라 권한 미작동 | `flutter_webrtc` + macOS 권한 연동 미검증 | 실제 빌드·런처로 확인 |
| Windows 오디오 라우팅 | 마이크/스피커 라우팅 환경 차이 | 실기기 테스트 |
| Intel Mac x64 | Apple Silicon 우선 | 별도 빌드 테스트 |
| 백그라운드 수신 | VoIP PushKit 미구현 | iOS/Android와 동일 패턴으로 확장 |

---

## 7. 관련 문서

- [[wiki/02_Design/macOS-client-design]]
- [[wiki/02_Design/macOS-client-ui]]
- [[wiki/02_Design/macOS-client-roadmap]]
- [[wiki/02_Design/mobile-client]]
- [[wiki/02_Design/sip-client-design]]
- [[wiki/05_Decisions/ADR-002]]
- [[wiki/05_Decisions/ADR-003]]

---

*본 문서는 2026-11-08 기준으로 작성되었으며, 이후 실제 개발 진행에 따라 갱신된다.*
