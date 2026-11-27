# SmartCC_Kibal-Client

SmartCC_Kibal(Asterisk 22 LTS)과 연동하는 멀티플랫폼 SIP 영상통화 클라이언트.

## 핵심 문서

- [작업지시서](docs/작업지시서.md) - **단일 관리 원본(영속 규칙/승격/릴리스/검수)**
- [CLAUDE.md](CLAUDE.md) - 에이전트 포인터
- [AGENTS.md](docs/AGENTS.md) - 에이전트 메모리 요약 포인터
- [4환경 Git 운영규약](wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md)
- [작업 시작 전 준수 지시서](wiki/04_Prompts/20261127_작업시작전_준수지시서_읽기_규약_v1.0.md)
- [NAS 접근 경로](wiki/09_Knowledge/20261127_NAS_접근경로_영속기록_v1.0.md)

## 환경 요약

| 구분 | 값 |
|------|----|
| DEV SIP/OPS | `192.168.11.5` / `8091` |
| TEST SIP/OPS | `192.168.11.5` / `15060,18088,18089,RTP11000-11100` / `18091` |
| 시각 | 서버 UTC, 클라이언트·OPS KST(+9h) |

## 운영 규칙 요약

- 검수 전 변경: `test/*` 작업브랜치에만 커밋/푸시.
- PASS 후 DEV 승격, 승인 후 PRD/EXTERNAL 승격.
- DEV/PRD/배포용 DMG: 버전 상향+release+SHA256 보고.
- TEST 검수용 DMG: `--no-bump` 허용, 브랜치/해시/경로/SHA256/검증 결과 보고, 산출물 git 미커밋.
- `git add -A` 금지, 명시 파일만 stage.

## 빠른 점검

```bash
git fetch --all --prune
git status --short
git branch --show-current
cd macos-client && flutter analyze && flutter test
```

## Wiki

- `wiki/01_Projects` 계획/태스크
- `wiki/02_Design` 설계
- `wiki/03_Guides` 운영 가이드
- `wiki/04_Prompts` 작업 지시
- `wiki/06_Reports` 보고서
- `wiki/07_Logs` 작업/교차 로그
- `wiki/09_Knowledge` 지식/영속 기록
