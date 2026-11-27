# SmartCC_Kibal-Client — Claude Code 프로젝트 지침

> **단일 관리 원본**: `docs/작업지시서.md` (사용자가 수정/관리).  
> 이 파일과 `docs/AGENTS.md`는 에이전트/도구 호환용 포인터이며, 규칙 충돌 시 `docs/작업지시서.md`를 따른다.

## 필수 참조
- [작업지시서](docs/작업지시서.md) — 영속 규칙/승격/릴리스/검수 단일 원본
- [AGENTS](docs/AGENTS.md) — 에이전트 메모리 요약 포인터
- [4환경 Git 운영규약](wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md)
- [작업 시작 전 준수 지시서](wiki/04_Prompts/20261127_작업시작전_준수지시서_읽기_규약_v1.0.md)
- [NAS 접근 경로](wiki/09_Knowledge/20261127_NAS_접근경로_영속기록_v1.0.md)

## 작업 시작 전
1. `docs/작업지시서.md` 확인
2. `git status --short`, `git branch --show-current` 확인
3. 검수 전 변경은 `test/*` 브랜치에만 커밋/푸시, `git add -A` 금지
4. DMG/버전 발행은 `docs/작업지시서.md` 4.5 릴리스/DMG 규칙 준수

## 언어
- 특별 지시 없으면 한국어로 응답·문서·로그·커밋 메시지 작성.
