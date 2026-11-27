# 20261127 Server-Client 교차 진행 로그

- 문서번호: `KIBAL-CLIENT-CROSSLOG-20261127-v1.0`
- 상태: 진행중(영속)
- 목적: Server(`SmartCC_Kibal`)와 Client(`SmartCC_Kibal-Client`)의 분리검수/릴리스/장애 대응 진행 상황을 양쪽 wiki에 교차 기록.

## 운영 규칙 (영속)

1. Server/Client에 영향을 주는 결정·검수·릴리스·장애·승격은 **양쪽 repo wiki에 같은 날짜 로그를 남긴다**.
2. 각 로그에는 최소 `시각(KST) / 작업자 / 저장소 / 브랜치 / 커밋 / 상태 / 다음 액션 / 상대 repo 문서 경로`를 포함한다.
3. 상세 산출물은 해당 repo에 두고, 상대 repo에는 요약+경로+커밋 해시를 남긴다.
4. `git add -A` 금지. 로그/규약/지시서 등 명시 파일만 커밋.
5. 검수 전 변경은 TEST 성격 브랜치에 기록. PASS 후 DEV 승격 이력도 양쪽에 남긴다.

## 현재 상태

| 시각(KST) | 저장소 | 브랜치/커밋 | 상태 | 요약 | 다음 액션 |
|---|---|---|---|---|---|
| 2026-11-26 | Server | `feature/external-network-wss` / `1dcc3a0` | 지시서 발행 | v0.0.64 버전복구·분리검수 지시서 발행 | 답변서 수신/리뷰 |
| 2026-11-26 | Client | `feature/external-network-access` / `4af92345` | 규약 반영 | 4환경 분리·검수 승격 규약 영속 반영 | 답변서 지정 경로 push |
| 2026-11-27 14:28 | Server | `feature/external-network-wss` / 작업중 | 답변서 미확인 | Server fetch 기준 답변서 `eea01b6` 미확인 | Client push 위치 확인 |
| 2026-11-27 14:28 | Client | `feature/external-network-access` / `4af92345` | 대기 | 답변서 파일/커밋을 지정 경로에 push 필요 | 아래 지정 경로로 push 후 해시 공유 |
| 2026-11-27 18:08 | Client/Server | Client `562420b5` / Server `80444bf` | 절차서 작성 | 로그 동기화 확인 절차서를 양쪽 wiki에 작성하고 커밋/런타임 로그 판정 결과 상호 참조 | TEST 브랜치 푸시, DEV 승격 보류 |
| 2026-11-27 18:29 | Client/Server | Client `44fdc5e7` / Server `9ddf207` | 보고서 작성 | DMG 공유폴더 자동발행 보고서를 양쪽 wiki에 작성하고 공통 산출물/SHA256 상호 참조 | MacBook/MacBookAir 재현 검증, DEV 승격 보류 |
| 2026-11-27 18:31 | Client/Server | Client `6acf8c77` / Server `6fbed05` | 전체 요약 | 오늘 작업 전체와 Server AI 인계 P0/P1/P2를 양쪽 wiki에 상호 참조 | 1102 408 분석, 6700 실기 PASS, 다단말 발행 검증 |

## 답변서 지정 경로

- 브랜치: `origin/feature/external-network-access`
- 파일: `wiki/04_Prompts/20261126_Client_v0.0.64_버전복구_분리검수_작업지시서_답변서_v1.0.md`
- push 후 공유: 커밋 해시, `git show --name-only <hash>`

## 상세 이력

### 2026-11-27 14:28 KST

- **Server 작업자**: Codex
- **Server 문서**: `SmartCC_Kibal/wiki/07_Logs/20261127_Server-Client_교차진행로그.md`
- **상태**: Server가 Client 답변서 위치 미확인. 양쪽 교차 로그 규약을 영속화.
- **Client 필요 조치**: 답변서 지정 경로 push, 해시/파일목록 공유.

### 2026-11-27 14:45 KST - Server 리뷰 결과 반영

- **Server 작업자**: Codex
- **Server 리뷰 커밋**: `SmartCC_Kibal` `wiki/06_Reports/20261127_Client_v0.0.64_버전복구_지시서답변_리뷰보고서_v1.0.md` (push 예정)
- **판정**: 조건부 승인(빌드 산출물), DEV 승격 보류.
- **Client 필요 조치**:
  1. `test/client-v0.0.64-recovery` 브랜치 생성/push
  2. 6700 재입장 3회 실기 PASS 증거(`wiki/08_Experiments/20261127_6700재입장_v0.0.64_검증기록_v1.0.md`)
  3. 로그는 `usr=` 기준 판정, NAS 공유 경로/대체 경로 명시
  4. NAS 4949 복구 시 dev/prd 선행 재확인
- **상대 문서**: `SmartCC_Kibal/wiki/07_Logs/20261127_Server-Client_교차진행로그.md`

## 작업 시작 전 준수 지시서 읽기 규약 제정 (2026-11-27)

- Server와 동일한 규약을 Client `wiki/04_Prompts/20261127_작업시작전_준수지시서_읽기_규약_v1.0.md`에 제정, CLAUDE.md에 포인터 추가.
- 매 작업 시작 시 지시서/영속규약/버전·브랜치 상태 확인 후 착수. "진행해"는 정책 준수 전제.
- 현재: origin/feature=`9cddfb08`(v0.0.65), origin/test=`aa52367f`(v0.0.66 TEST 산출물). 실기 PASS 전 DEV 승격 금지.

### 2026-11-27 18:08 KST - 로그 동기화 확인 절차서

- **Client 문서**: `wiki/03_Guides/20261127_로그동기화_확인절차서_v1.0.md`
- **Client 커밋**: `562420b5` (`test/client-v0.0.64-recovery`)
- **Server 문서**: `SmartCC_Kibal/wiki/03_Guides/20261127_로그동기화_확인절차서_v1.0.md`
- **Server 커밋**: `80444bf` (`test-pending-log-sync`)
- **확인 결과**: Client 커밋 로그 `5c3f74f9` 로컬/원격 일치. 1102(v0.0.66)/1104(v0.0.64) OPS `mirror_ok=true` 및 NAS 일자별 파일 최신 로그 일치.
- **주의**: AI봇 7001의 OPS/NAS 클라이언트 로그 파일은 없음. AI 작업 커밋 로그와 AI봇 런타임 로그는 별도 축으로 확인.
- **다음 액션**: 양쪽 TEST 브랜치에 명시 커밋/푸시. DEV 승격 없음.
- **브랜치명 보완**: Server 원격에 `test` 기준 브랜치가 있어 `test/...` ref 생성이 거절됨. `test-pending-log-sync`로 변경해 force 없이 push.

### 2026-11-27 18:29 KST - DMG 공유폴더 자동발행 보고서

- **Client 보고서**: `wiki/06_Reports/20261127_DMG_공유폴더_자동발행_보고서_v1.0.md`
- **Client 보고서 커밋**: `44fdc5e7`
- **Server 보고서**: `SmartCC_Kibal/wiki/06_Reports/20261127_DMG_공유폴더_자동발행_보고서_v1.0.md`
- **Server 보고서 커밋**: `9ddf207`
- **구현 커밋**: Client `5420f62f`
- **공통 산출물**: `/Volumes/NetBackup/보관함/개발/Live_Log/macOS_Client_v0.0.66.dmg`
- **SHA256**: `58b3f5b4b454e1fa1082f61af6d1c1df2b90d7d4c4d28836d8fe6a83096bda58`
- **다음 액션**: MacBook/MacBookAir SMB 마운트·빌드·자동 발행 재현 검증. DEV 승격 없음.

### 2026-11-27 18:31 KST - 오늘 작업 전체 요약보고서

- **Client 보고서**: `wiki/06_Reports/20261127_오늘작업_전체요약보고서_v1.0.md`
- **Client 커밋**: `6acf8c77`
- **Server 보고서**: `SmartCC_Kibal/wiki/06_Reports/20261127_오늘작업_전체요약보고서_v1.0.md`
- **Server 커밋**: `6fbed05`
- **인계 대상**: Server AI agent
- **P0**: v0.0.66 승격 보류, 1102 408/ICE 분석, 6700 실기 PASS
- **P1**: MacBook/MacBookAir SMB 마운트·빌드·공통 발행 재현
- **P2**: AI봇 7001 런타임 로그 경로 확인

### 2026-11-27 20:15 KST - TEST OPS manifest 오염 수정/검증/문서 규칙 강화

- **Server 작업자**: opencode
- **Server 브랜치**: `feature/external-network-wss`
- **Server 커밋**: `2cde3f5`(발행 보고 규칙 강화), `38b3447`(profile manifest canonical 엔드포인트 오염 방지)
- **Client 브랜치/커밋**: `test/client-v0.0.64-recovery` / `2dac7863`(발행 보고 규칙 강화)
- **검증**:
  - Server `py_compile server/ops/api/app/routes.py` PASS
  - TEST OPS `/api/client/config` 실응답: `dev=8091/5060/8088`, `prd=192.168.11.3:8091/5060/8088`, `external=appletreeda.synology.me:18091/5060/wss:8089`, `test=18091/15060/18088`, `default_profile=test`
- **정책 반영**: 양쪽 `docs/작업지시서.md` 4.6에 클라이언트 발행 보고 필수 블록 강제.
- **Client 실기 차단**: TEST 검수 DMG(`--no-bump`) 미빌드, 1101/1102 TEST 18088/15060 재등록 및 1:1/6000/6100/6700 실기 미수행.
- **상대 문서**: `SmartCC_Kibal/wiki/07_Logs/20261127_Server-Client_교차진행로그.md`
