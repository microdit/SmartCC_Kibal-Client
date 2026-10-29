# SmartCC_Kibal-Client — Claude Code 프로젝트 지침

> **지속 사용 기록**: 이 프로젝트에서 지속 사용하는 자동화 도구와 관리 파일의 영구 기록.
> 전체 프로토콜은 `docs/작업지도.md`(Knowledge OS v3.0), 에이전트 메모리는 `docs/AGENTS.md`를 따른다.

**날짜**: 2026-10-29
**버전**: v1.0

---

## 프로젝트 개요

- **SmartCC Kibal Client (스마트CC 키발 클라이언트)**: Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 멀티플랫폼 SIP 영상통화 클라이언트
- **Web Client**: React + TypeScript + SIP.js + WebRTC (브라우저 기반 1:1/다자간 영상통화)
- **Mobile Client**: Flutter + flutter_webrtc (iOS / Android 네이티브 앱)
- **별도 리포지토리**: `git@github.com:microdit/SmartCC_Kibal-Client.git`
- **운영 철학**: Server와 동일 — Knowledge OS v3.0 (9-Layer Wiki), Git 3-Way, ChromaDB Vector DB

---

## 지속 사용 자동화 도구

| 도구 | 용도 | 사용 예 |
|------|------|---------|
| `scripts/git-sync.sh` | 커밋 + 전체 remote 푸시 + 자동 로그 | `./scripts/git-sync.sh --auto` |
| `scripts/generate-commit-msg.py` | 커밋 메시지 자동 생성 | git-sync.sh가 내부 호출 |
| `scripts/log.py` | 작업/이벤트 로그 기록 | git-sync.sh가 내부 호출 |
| `scripts/index_wiki.py` | Wiki 문서 ChromaDB 인덱싱 | `python scripts/index_wiki.py --reindex` |
| `docs/AGENTS.md` | 작업 지시서 (Knowledge OS Kernel) | 매 작업 전 반드시 확인 |
| `docs/작업지도.md` | Knowledge OS v3.0 Kernel | 프로젝트 요구사항 정의서 |
| `docs/_작업이력/{오늘날짜}.md` | 작업 로그 (커밋 메시지 자동 생성용) | 매 작업 마지막에 작성 |
| `docs/_작업이력/log/*.md` | git-sync.sh 자동 생성 로그 | .gitignore에서 관리 |

## 지속 관리 파일

| 파일 | 용도 |
|------|------|
| `CLAUDE.md` | Claude Code 프로젝트 지침 (영구 기록) |
| `docs/AGENTS.md` | Knowledge OS v3.0 작업 지시서 |
| `docs/작업지도.md` | 프로젝트 요구사항 정의서 |
| `agent_wiki_vector.py` | ChromaDB Vector Store 엔진 |
| `.gitignore` | Git 무시 파일 목록 |
| `requirements.txt` | Python 의존성 |

## Git Remote 구조

| 리모트 | 용도 | URL 패턴 |
|--------|------|---------|
| `github` | 소스 of truth (GitHub) | `git@github.com:microdit/SmartCC_Kibal-Client.git` |
| `dev` | 개발 환경 (Local) | `ssh://atom@nas2:4949/var/services/homes/atom/gitRepo/SmartCC_Kibal-Client.git` |
| `prd` | 운영 환경 (NAS) | `ssh://atom@nas2:4949/var/services/homes/atom/gitRepo/SmartCC_Kibal-Client_prd.git` |

---

## 상태 (2026-10-29)

- **Knowledge OS v3.0 초기 구축 완료**: 9-Layer Wiki 구조, Git 자동화 스크립트, ChromaDB Vector Store
- **Git 초기 커밋 예정**: `feat: SmartCC_Kibal-Client Knowledge OS`
- **GitHub private repo 푸시 예정**: `git@github.com:microdit/SmartCC_Kibal-Client.git`
- **Wiki 구조**: client-project-plan, tasks, architecture, sip-client-design, ADR-001 등
- **스크립트**: git-sync.sh, generate-commit-msg.py, log.py, index_wiki.py
- **ChromaDB Vector Store 검증 예정**: chromadb 1.5.9 (Python 3.11 venv)
- **Client 리포지토리 분리 결정**: Server(`SmartCC_Kibal`)와 별도 리포지토리로 개발 — server의 기획 문서 `docs/기획/멀티플랫품-SIP-clients.md` 리뷰 완료