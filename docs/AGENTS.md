# AGENTS.md — Agent Memory v3.0

## 프로젝트 정의
- **프로젝트명**: SmartCC_Kibal-Client (멀티플랫폼 SIP 영상통화 클라이언트)
- **목적**: Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 Web (React + SIP.js) + macOS/모바일 (Flutter) 클라이언트 개발
- **버전**: Knowledge OS v3.0 (2026-10-29)
- **별도 리포지토리**: `git@github.com:microdit/SmartCC_Kibal-Client.git`

## 환경
| 구분 | 경로/IP | 비고 |
|------|---------|------|
| DEV (SIP 서버) | `192.168.11.39` | Docker: `kibal-dev-asterisk`(dev), `kibal-dev-ops`(ops) |
| Client workspace | `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client` | macOS |
| GitHub | `git@github.com:microdit/SmartCC_Kibal-Client.git` | origin |
| Python venv | `./venv_client/` | Python 3.11 + chromadb 1.5.9 |
| Web | `./web/` | React + TypeScript + Vite |
| Mobile/macOS | `./mobile/`, `./macos-client/` | Flutter 3.x (macOS/모바일) |

## 핵심 컴포넌트
| 컴포넌트 | 파일/경로 | 설명 |
|----------|-----------|------|
| Vector Store | `agent_wiki_vector.py` | ChromaDB 기반 Wiki 의미 검색 (collection: `kibal_client_wiki`) |
| 인덱싱 CLI | `scripts/index_wiki.py` | `--reindex`, `--search`, `--stats` |
| Git 동기화 | `scripts/git-sync.sh` | github/dev/prd 3-way push. **2026-11-09: `dev`/`prd`(NAS) 경로 재확인 필요** |
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
| dev | `ssh://atom@nas2:4949/var/services/homes/atom/gitRepo/SmartCC_Kibal-Client.git` | **NAS 실제 경로 재확인 필요(2026-11-09)** |
| prd | `ssh://atom@nas2:4949/var/services/homes/atom/gitRepo/SmartCC_Kibal-Client_prd.git` | **NAS 실제 경로 재확인 필요(2026-11-09)** |

## 배포·동기화 절차 (2026-11-03 확정)
1. `docs/_작업이력/{오늘날짜}.md`, `wiki/07_Logs/`, `wiki/06_Reports/`를 먼저 작성한다.
2. 클라이언트는 `./scripts/git-sync.sh "커밋 메시지" --no-deploy`를 사용한다.
   - 커밋 → `origin`/`dev`/`prd` 푸시까지 수행한다.
   - 현재 PRD 배포 파이프라인(Stage C4)은 없으므로 배포는 생략한다.
3. 웹 빌드 산출물은 커밋하지 않고, 검증은 `web`에서 `npm run build`와 스모크 스크립트로 수행한다.
4. SFU 다중 영상 수정 시 `web/src/sip/SipClient.ts`와 `web/scripts/browser-smoke.mjs`를 함께 갱신한다.
5. `git-sync.sh`는 `git add -A`를 사용하므로 실행 전 `git status --short`로 포함 파일을 확인한다.

## 커밋 타입
- `feat`: 새 기능
- `fix`: 버그 수정
- `chore`: 유지보수/환경설정
- `docs`: 문서 작성/수정
- `design`: 설계서 작성

## 현재 진행 (2026-11-11)
- 원격 오디오 H1/미디어 H4/H5(re-INVITE 미응답) 해결 → v0.0.8
- MediaManager 다중 영상(dedup + 트랙별 렌더 스트림) 수정 → v0.0.9+9
- 오디오 단독 118초 유지(v0.0.7)
- 잔여: v0.0.8(H5) / v0.0.9(3자 타일) 실기 재검증, `Sent RTP type 100` 확인
- 포크: `macos-client/packages/sip_ua` (ADR-005) — `dependency_overrides` 사용
- 상세: [[wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0]]
- 다음 작업: [[wiki/04_Prompts/20261111_원격오디오_ICE_후속작업프롬프트_v1.0]]

## 참조 문서
- [[docs/작업지도]] — Knowledge OS v3.0 Kernel
- [[wiki/01_Projects/client-project-plan]] — 클라이언트 프로젝트 계획
- [[wiki/02_Design/architecture]] — 시스템 아키텍처
- [[wiki/01_Projects/tasks]] — 작업 계획 및 마일스톤
- [[wiki/02_Design/sip-client-design]] — SIP Client 설계
- [[wiki/05_Decisions/ADR-004]] — SIP 엔진 sip_ua 교체 결정 기록
- [[wiki/05_Decisions/ADR-001-webrtc-over-flutter]] — WebRTC 우선 결정 기록