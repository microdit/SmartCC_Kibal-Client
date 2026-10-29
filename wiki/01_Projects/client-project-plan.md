# Kibal Client Project Plan

| 항목 | 내용 |
|------|------|
| **프로젝트명** | SmartCC_Kibal-Client (멀티플랫폼 SIP Client) |
| **별도 리포지토리** | `git@github.com:microdit/SmartCC_Kibal-Client.git` |
| **운영 철학** | SmartCC_Kibal과 동일 (Knowledge OS v3.0, 9-Layer Wiki, Git 3-Way, ChromaDB) |
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 계획 중 |
| **관련** | [[wiki/01_Projects/project-brief]], [[wiki/02_Design/architecture]] |

## 1. 프로젝트 개요

Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 **멀티플랫폼 SIP 영상통화 클라이언트**를 별도 리포지토리로 개발합니다.

## 2. 아키텍처

```
┌─────────────────────────────────────────┐
│           Kibal Client (신규)            │
│                                        │
│  ┌──────────────┐  ┌──────────────┐   │
│  │   React SPA   │  │  Flutter App │   │
│  │  (Web/Browser) │  │ (iOS/Android)│   │
│  └──────┬───────┘  └──────┬───────┘   │
│         │              │               │
│         └──────┬───────┘              │
│                │                      │
│         ┌──────▼──────┐               │
│         │  SIP.js /   │               │
│         │FlutterWebRTC│               │
│         └──────┬──────┘               │
└───────────────┼──────────────────────┘
                │ WebSocket (SIP/TLS)
┌───────────────▼──────────────────────┐
│           Kibal Server               │
│   (기존 SmartCC_Kibal 리포지토리)         │
│   - Asterisk 22 LTS                  │
│   - PJSIP / ConfBridge SFU           │
└──────────────────────────────────────┘
```

## 3. 기술 스택

| 계층 | 기술 | 버전 |
|------|------|------|
| Web Client | React + TypeScript + SIP.js + WebRTC | 18 / latest |
| Mobile Client | Flutter + flutter_webrtc + flutter_sip | 3.x |
| 빌드 도구 | Vite (Web), Flutter CLI (Mobile) | - |
| 상태 관리 | Zustand (Web), Provider (Mobile) | - |
| 스타일링 | Tailwind CSS | v3 |
| 테스트 | Jest (Web), flutter_test (Mobile) | - |

## 4. 프로젝트 구조 (Knowledge OS v3.0 적용)

```
SmartCC_Kibal-Client/
├── CLAUDE.md                    ← Agent Memory (L5)
├── docs/
│   ├── 작업지시서.md              ← Knowledge OS Kernel (L7)
│   ├── AGENTS.md                ← Agent Memory v3.0 (L5)
│   └── _작업이력/
│       └── log/                 ← git-sync 자동 로그 (.gitignore)
├── wiki/
│   ├── 01_Projects/             ← project-brief, tasks, client-project-plan
│   ├── 02_Design/               ← architecture, docker-setup, sip-client-design
│   ├── 03_Guides/               ← usage-guide, development-guide
│   ├── 04_Prompts/              ← work-commands
│   ├── 05_Decisions/            ← ADR-001~ADR-N (WebRTC, NAT, 코덱 등)
│   ├── 06_Reports/              ← 완료 보고서
│   ├── 07_Logs/                 ← 작업 로그
│   ├── 08_Experiments/          ← Web Client 실험, Flutter 실험
│   └── 09_Knowledge/            ← SIP.js API, WebRTC 참고 자료
├── scripts/
│   ├── git-sync.sh              ← github/dev/prd 3-way push
│   ├── index_wiki.py            ← ChromaDB 인덱싱
│   ├── generate-commit-msg.py   ← 커밋 메시지 자동 생성
│   └── log.py                   ← 작업 로그
├── agent_wiki_vector.py         ← ChromaDB Vector Store (재사용)
├── venv_client/                 ← Python 3.11 venv (chromadb 1.5.9)
├── vector_db/                   ← ChromaDB Persistent DB
├── web/                         ← React Web Client (src, public, index.html)
├── mobile/                      ← Flutter Mobile Client (lib/, android/, ios/)
├── docker-compose.yml           ← Web + Nginx 컨테이너
├── Dockerfile.web               ← React 빌드 이미지
├── Dockerfile.api               ← (선택) Flask API 브리지
└── requirements.txt             ← chromadb 1.5.9 등
```

## 5. Git Remote (3-Way 동기화)

| 리모트 | 용도 | URL (예정) |
|--------|------|-------------|
| `github` | Source of truth | `git@github.com:microdit/SmartCC_Kibal-Client.git` |
| `dev` | DEV 환경 | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client.git` |
| `prd` | PRD 환경 | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client_prd.git` |

## 6. 운영 철학 (Same as Kibal Server)

| 항목 | Kibal Server | Kibal Client |
|------|-------------|--------------|
| Knowledge OS | v3.0 (9-Layer) | ✅ 동일 |
| Git workflow | 3-Way sync | ✅ 동일 |
| Vector DB | ChromaDB 1.5.9 | ✅ 재사용 |
| Python venv | venv_kibal (3.11) | venv_client (3.11) |
| Agent Memory | CLAUDE.md + AGENTS.md | ✅ 동일 |
| 커밋 규칙 | feat/fix/chore/docs/design | ✅ 동일 |
| 작업 로그 | docs/_작업이력/ | ✅ 동일 |

## 7. 단계별 로드맵

| 단계 | 목표 | 완료 조건 | 상태 |
|------|------|----------|------|
| **Stage C1** | 프로젝트 초기화 | Git 저장소 + Wiki 구조 + venv | 미진행 |
| **Stage C2** | Web Client MVP | 1:1 영상통화 (React + SIP.js) | 미진행 |
| **Stage C3** | Mobile Client | Flutter iOS/Android 빌드 | 미진행 |
| **Stage C4** | Docker 배포 | Web 클라이언트 컨테이너화 | 미진행 |
| **Stage C5** | 통합 테스트 | Server + Client 3자 회의 검증 | 미진행 |

## 8. PoC 테스트 체크리스트

| 테스트 ID | 설명 | 완료 |
|-----------|------|------|
| CT01 | SIP.js 등록 (Web) | ☐ |
| CT02 | 1:1 영상통화 (Web) | ☐ |
| CT03 | Flutter SIP 등록 (Mobile) | ☐ |
| CT04 | 1:1 영상통화 (Mobile) | ☐ |
| CT05 | 3자 SFU 회의 (Web) | ☐ |
| CT06 | NAT 통과 (STUN) | ☐ |

## 9. 관련 문서

- [[wiki/01_Projects/project-brief]] — Kibal Server 프로젝트 브리프
- [[wiki/02_Design/architecture]] — Kibal Server 시스템 아키텍처
- [[wiki/02_Design/docker-setup]] — Kibal Server Docker 설계
- [[wiki/05_Decisions/ADR-001]] — Asterisk 22 LTS 결정