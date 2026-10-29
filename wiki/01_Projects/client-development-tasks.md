# Kibal Client 개발 작업 분해 (Client Development Tasks)

| 항목 | 내용 |
|------|------|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 계획 중 |
| **관련** | [[wiki/01_Projects/client-project-plan]], [[wiki/01_Projects/tasks]] |

> **별도 리포지토리**: `SmartCC_Kibal-Client`

---

## 1. 단계별 작업 목록

### Stage C1: 프로젝트 초기화

| 작업 ID | 설명 | 담당 | 완료 |
|---------|------|------|------|
| C1-01 | Git 저장소 생성 (GitHub) | - | ☐ |
| C1-02 | Remote 3-Way 설정 (github/dev/prd) | - | ☐ |
| C1-03 | 9-Layer Wiki 디렉토리 구조 생성 | - | ☐ |
| C1-04 | Python 3.11 venv 생성 (`venv_client`) | - | ☐ |
| C1-05 | ChromaDB 1.5.9 설치 | - | ☐ |
| C1-06 | agent_wiki_vector.py 복사 | - | ☐ |
| C1-07 | git-sync.sh 스크립트 복사 | - | ☐ |
| C1-08 | CLAUDE.md, docs/AGENTS.md 작성 | - | ☐ |

### Stage C2: Web Client MVP (MVP-1)

| 작업 ID | 설명 | 기술 | 완료 |
|---------|------|------|------|
| C2-01 | React + TypeScript + Vite 프로젝트 생성 | React 18 | ☐ |
| C2-02 | Tailwind CSS 설정 | Tailwind v3 | ☐ |
| C2-03 | Zustand 상태 관리 설정 | Zustand | ☐ |
| C2-04 | SIP.js UserAgent 구현 | SIP.js | ☐ |
| C2-05 | REGISTER 테스트 (CT01) | WebSocket/WSS | ☐ |
| C2-06 | getUserMedia 구현 | WebRTC | ☐ |
| C2-07 | 1:1 INVITE/Session 구현 | SIP.js + WebRTC | ☐ |
| C2-08 | SDP Offer/Answer 처리 | WebRTC | ☐ |
| C2-09 | 1:1 영상통화 테스트 (CT02) | H.264/Opus | ☐ |
| C2-10 | 로그인/Dialer/Call UI 구현 | React + Tailwind | ☐ |
| C2-11 | 브라우저 호환성 테스트 | Chrome/Edge/Safari/Firefox | ☐ |

### Stage C3: Mobile Client (MVP-2)

| 작업 ID | 설명 | 기술 | 완료 |
|---------|------|------|------|
| C3-01 | Flutter 프로젝트 생성 | Flutter 3.x | ☐ |
| C3-02 | flutter_webrtc + flutter_sip 추가 | flutter_webrtc | ☐ |
| C3-03 | SIP 등록 구현 (CT03) | flutter_sip | ☐ |
| C3-04 | 1:1 영상통화 구현 (CT04) | flutter_webrtc | ☐ |
| C3-05 | iOS/Android 권한 설정 | Info.plist/AndroidManifest | ☐ |
| C3-06 | 모바일 UI (Dialer/Call/Conference) | Flutter + Provider | ☐ |

### Stage C4: Docker 배포

| 작업 ID | 설명 | 완료 |
|---------|------|------|
| C4-01 | Web Client Dockerfile 작성 | ☐ |
| C4-02 | nginx.conf 작성 | ☐ |
| C4-03 | docker-compose.yml 작성 | ☐ |
| C4-04 | Production 빌드 테스트 | ☐ |
| C4-05 | Reverse Proxy (Nginx/Caddy) 설정 | ☐ |

### Stage C5: 통합 테스트

| 작업 ID | 설명 | 검증 방법 | 완료 |
|---------|------|---------|------|
| C5-01 | 3자 SFU 회의 (CT05) | 3브라우저 → 6000번 | ☐ |
| C5-02 | NAT 통과 (CT06) | 공인망 접속 | ☐ |
| C5-03 | Server + Client 3자 회의 | 실시간 검증 | ☐ |

### Stage C6: Native iOS (향후)

| 작업 ID | 설명 | 기술 | 완료 |
|---------|------|------|------|
| C6-01 | iOS 프로젝트 생성 | Swift/UIKit | ☐ |
| C6-02 | PJSIP XCFramework 통합 | PJSIP | ☐ |
| C6-03 | VoIP (PushKit) 설정 | PushKit | ☐ |
| C6-04 | App Store 배포 준비 | Xcode Archive | ☐ |

---

## 2. PoC 테스트 체크리스트

| 테스트 ID | 설명 | 완료 |
|-----------|------|------|
| CT01 | SIP.js 등록 (Web) | ☐ |
| CT02 | 1:1 영상통화 (Web) | ☐ |
| CT03 | Flutter SIP 등록 (Mobile) | ☐ |
| CT04 | 1:1 영상통화 (Mobile) | ☐ |
| CT05 | 3자 SFU 회의 (Web) | ☐ |
| CT06 | NAT 통과 (STUN) | ☐ |

---

## 3. 관련 문서

- [[wiki/01_Projects/client-project-plan]] — 클라이언트 프로젝트 계획
- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 설계
- [[wiki/02_Design/web-client]] — Web Client 설계
- [[wiki/02_Design/mobile-client]] — Mobile Client 설계
- [[wiki/03_Guides/development-guide]] — 개발 가이드