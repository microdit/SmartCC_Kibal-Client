# AGENTS.md — Agent Memory v3.0

## 프로젝트 정의
- **프로젝트명**: SmartCC_Kibal-Client (멀티플랫폼 SIP 영상통화 클라이언트)
- **목적**: Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 Web (React + SIP.js) + Mobile (Flutter) 클라이언트 개발
- **버전**: Knowledge OS v3.0 (2026-10-29)
- **별도 리포지토리**: `git@github.com:microdit/SmartCC_Kibal-Client.git`

## 환경
| 구분 | 경로/IP | 비고 |
|------|---------|------|
| DEV | `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client` | macOS |
| GitHub | `git@github.com:microdit/SmartCC_Kibal-Client.git` | 추후 생성 |
| Python venv | `./venv_client/` | Python 3.11 + chromadb 1.5.9 |
| Web | `./web/` | React + TypeScript + Vite |
| Mobile | `./mobile/` | Flutter 3.x |

## 핵심 컴포넌트
| 컴포넌트 | 파일/경로 | 설명 |
|----------|-----------|------|
| Vector Store | `agent_wiki_vector.py` | ChromaDB 기반 Wiki 의미 검색 (collection: `kibal_client_wiki`) |
| 인덱싱 CLI | `scripts/index_wiki.py` | `--reindex`, `--search`, `--stats` |
| Git 동기화 | `scripts/git-sync.sh` | github/dev/prd 3-way push |
| 작업지도 | `docs/작업지도.md` | Knowledge OS Kernel |
| 기획 리뷰 | `docs/기획/` | 서버 기획 문서 리뷰 의견 |

## 작업 규범
1. 항상 CLAUDE.md 확인 후 작업
2. `docs/_작업이력/{오늘날짜}.md`에 작업 로그 작성 (커밋 메시지 자동 생성용)
3. `docs/AGENTS.md`를 업데이트하며 작업
4. 위키 문서는 9-Layer 구조에 맞게 분류 (`wiki/01_Projects` ~ `wiki/09_Knowledge`)
5. `git-sync.sh --auto --no-deploy`로 커밋 및 3-way 동기화
6. Client 리포지토리는 Server(`SmartCC_Kibal`)와 분리 — cross-reference는 위키 링크로 참조

## Git Remote (3-way)
| 리모트 | URL |
|--------|-----|
| github | `git@github.com:microdit/SmartCC_Kibal-Client.git` |
| dev | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client.git` |
| prd | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client_prd.git` |

## 커밋 타입
- `feat`: 새 기능
- `fix`: 버그 수정
- `chore`: 유지보수/환경설정
- `docs`: 문서 작성/수정
- `design`: 설계서 작성

## 참조 문서
- [[docs/작업지도]] — Knowledge OS v3.0 Kernel
- [[wiki/01_Projects/client-project-plan]] — 클라이언트 프로젝트 계획
- [[wiki/02_Design/architecture]] — 시스템 아키텍처
- [[wiki/01_Projects/tasks]] — 작업 계획 및 마일스톤
- [[wiki/02_Design/sip-client-design]] — SIP Client 설계
- [[wiki/05_Decisions/ADR-001-webrtc-over-flutter]] — WebRTC 우선 결정 기록