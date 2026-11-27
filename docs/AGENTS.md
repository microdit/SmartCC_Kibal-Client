# AGENTS.md — Agent Memory v3.0 (요약 포인터)

> **단일 관리 원본**: [docs/작업지시서.md](docs/작업지시서.md)  
> 이 문서는 에이전트 호환용 요약이다. 규칙/절차 충돌 시 `docs/작업지시서.md`를 따른다.

## 핵심 규칙
- 작업 전: `docs/작업지시서.md` 확인 → `git status --short` → `git branch --show-current`.
- 검수 전 변경: `test/*` 작업브랜치에만 커밋/푸시. PASS 후 DEV 승격, 승인 후 PRD/EXTERNAL 승격.
- `git add -A` 금지, 명시 파일만 stage.
- 버전 사고 방지: `git fetch --all --prune`, 선행 보존+버전 상향, 역행 덮어쓰기/승인 없는 force push 금지.
- Server-Client 영향 사항: 양쪽 `wiki/07_Logs/YYYYMMDD_Server-Client_교차진행로그.md`에 같은 날짜 기록.
- 언어: 특별 지시 없으면 한국어.

## 릴리스 요약
- DEV/PRD/배포용 DMG: 버전 상향+release+커밋/푸시/SHA256 보고.
- TEST 검수용 DMG: `test/*`에서 `--no-bump` 허용, 브랜치/해시/경로/SHA256/검증 결과 보고, 산출물 git 미커밋.

## 참조
- [작업지시서](docs/작업지시서.md)
- [CLAUDE](../CLAUDE.md)
- [4환경 Git 운영규약](../wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md)
- [NAS 접근 경로](../wiki/09_Knowledge/20261127_NAS_접근경로_영속기록_v1.0.md)
