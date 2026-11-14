# AGENTS.md — Agent Memory v3.0

## 프로젝트 정의
- **프로젝트명**: SmartCC_Kibal-Client (멀티플랫폼 SIP 영상통화 클라이언트)
- **목적**: Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 Web (React + SIP.js) + macOS/모바일 (Flutter) 클라이언트 개발
- **버전**: Knowledge OS v3.0 (2026-10-29)
- **별도 리포지토리**: `git@github.com:microdit/SmartCC_Kibal-Client.git`

## 환경
| 구분 | 경로/IP | 비고 |
|------|---------|------|
| DEV (SIP 서버) | `192.168.0.3` | 2026-11-12 유선 전환(구 `192.168.11.39`). Docker: `kibal-dev-asterisk`(dev), `kibal-dev-ops`(ops) |
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
- MediaManager 다중 영상/렌더/타일 선택 보완 → v0.0.11+11
- v1.6 실기(3자): H5/ICE 안정, stale 트랙 누적 → 최신 3타일+선택 UI
- 잔여: 참가자 식별(서버 메타데이터), 1101 오디오 출력, 3자 재검증
- 클라이언트 로그 자동 수집(v0.0.12): `scripts/ops_client_logs.sh list|tail|follow`로 OPS 내선별 로그 조회
- 포크: `macos-client/packages/sip_ua` (ADR-005) — `dependency_overrides` 사용
- 상세: [[wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0]]
- 다음 작업: [[wiki/04_Prompts/20261111_원격오디오_ICE_후속작업프롬프트_v1.0]]

## 현재 진행 (2026-11-12)
- A10 P1 v0.0.21(장치 선택), P2 v0.0.22(H.264·6100) 빌드 완료, **실기 대기**
- A10 `192.168.0.12`: TEAMS EDITION, `byod` only, FW `278.320.0.86`
- USB B′: USB-C 연결됨, A10 `No sharing signal`, Mac에서 Yealink 미열거(`HD20K`만 USB 오디오) → 케이블/포트/macOS 승인 확인 필요
- SIP T0-C: A10 `talking=true`로 웹 UI `writeData` 중단 → `writeconfig` 없음. **이후 `#/account-sip` 저장으로 `1201` 등록 성공 확인**(중간보고서 v1.1)
- 서버: `1201` endpoint·`6100` `follow_talker` 준비됨. 현재 `6100`에 `PJSIP/1103-*` + `PJSIP/1201-*` 실통화 중
- 상세: [[wiki/06_Reports/20261112_A10_T0C_USB_중간보고서_v1.0]], [[docs/보고서/20261112_A10_T0C_USB_작업계획서_v1.0]], [[wiki/07_Logs/작업인계_20261112_A10_T0C]]

## 현재 진행 (2026-11-12 22:50) — 통화 품질 개선, 실행 순서 **C → A → D → B**
- **404 원인 확정·A 완료(A5 회귀 합격 23:58)**: 컨테이너 재생성으로 AOR 반영, 294초 갱신 구간 contact 해시 유지, 신규 404 0건, ADR-004 Accepted. `1102→1103`은 `1103` AOR contact 부재. 실측 — `register_expires=300`이 294초 주기 재REGISTER를 만들고 `remove_existing=yes`가 갱신마다 contact를 비움. 서버는 AOR 정책 변경(서버 리포 ADR-004), 클라이언트는 **A4** `transportStateChanged` 재연결 시 재REGISTER 보장(`sip_client.dart`, analyze 0 / test 17). 다이얼플랜·코덱 무관. 런타임 반영은 실통화 종료 후 컨테이너 재생성 필요
- 제공된 "1103 로그"는 실제 **1102 로그**(OPS `1102.log`). `01:05:30` 착신은 1102 self-call
- **C**: 발언자 **1201 자동설정** + 1103에 발언자 영상·음성 정상 수신 확인 → `follow_talker` 정상, `confbridge list` 빈 Flags를 "발화자 미선정"으로 읽은 것은 오진(기각). **설정 변경 불필요**. 잔여는 A10(1201) 화면 캡처 + 발화자 1103 전환 테스트(최초 증상은 1103→A10 방향이라 미검증). 상세 [[wiki/08_Experiments/20261112_C_발화자영상_검증_v1.0]]
- **D 완료(v0.0.23)**: D1 `_receiveOnlyVideo` + `_acceptReinvite` 옵션 병합(ADR-008 Accepted), D2 inactive 영상 스트림만 정리(오디오 전용 보존). analyze 0 / test 17 / DMG sha256 `ace1cf4…`(설치본 재빌드). D3 제공 로그는 v0.0.16 이하 빌드(`1102.meta.json` v0.0.19는 마지막 세션 기준)
- **B**: 손실 버스트 2회 / out-fps 붕괴(로컬 인코더) / 첫 키프레임 대기 3현상. 손실·freeze 카운터는 getStats **누적**이라 고정이 정상. B3 완료 — `01:15:03` `640x480` 하향은 앱 코드(`lowVideoConstraints` 미사용)가 아닌 **WebRTC 인코더 자체 적응**
- **배포(00:40)**: v0.0.23 `/Applications` 설치 완료(sha256 `ace1cf4…`). `1201` 재등록 해소, `1103` 자동 복구 확인 → [[wiki/08_Experiments/20261112_B_실기준비_v1.0]]

## 현재 진행 (2026-11-13 01:00) — 1:1 코덱 불일치·A4 회귀
- **`1201` 1:1 원격 영상 미수신 원인 확정**: 발신 offer에 H.264 정책 미적용(`remote_identity` null) → 1103 leg VP8 vs A10 H.264 only → Asterisk 영상 트랜스코딩 불가. 서버 UTC 15:40~15:41 = 클라이언트 KST 00:40~00:41 정확히 대응. 수정안 **F1** `SipSession.remoteParty` 폴백
- **v0.0.23 A4 회귀**: 재REGISTER가 1101 등록 루프 유발(다자간 튕김) → **F2 롤백 필요**. A5 합격은 서버 A3만으로 유지
- **6100 단독 입장 스피너(01:10)**: 코덱 문제 아님. `ConfbridgeSetSingleVideoSrc`가 *"all other participants"* 로 자기 자신 제외 → 참가자 1명이면 전달할 원격 영상 소스 0개, `confbridge.conf`에 `video_source` 없음, `Enable Events: no`로 카드도 미구성. 2번째 참가자 입장으로 해소 확인(G1) → 분석보고서 v1.1 10장, 지식 K16
- 상세: [[wiki/06_Reports/20261113_1201_1대1_영상미수신_교차분석보고서_v1.0]], [[wiki/08_Experiments/20261113_코덱불일치_로그교차검증_v1.0]], 지식 K14~K16

## 현재 진행 (2026-11-13 01:30) — F1/F2/G3 계획 확정
- **순서**: 문서·로그 → 검증 → 커밋/동기화 → **F1 → F2 → G3** 개발 → 검증·v0.0.24 → 결과 커밋
- **F1 정정**: `_currentSession` 폴백은 부정확 → **`_pendingCallTarget`**(`call()` 직전 설정, `_cleanupSession()` 초기화). 분석보고서 v1.2 7장 반영
- **F2**: [[wiki/05_Decisions/ADR-009-A4_재등록_롤백]] — A4 전면 롤백(1101 등록 루프)
- **G3**: 서버 리포 `ADR-005_ConfBridge_참가자이벤트_20261113` — `enable_events=yes`, `video_source`는 옵션 부재로 G2 보류
- 계획·테스트: [[docs/보고서/20261113_F1F2_G3_작업계획서_v1.0]], [[wiki/03_Guides/20261113_F1F2_G3_테스트절차서_v1.0]], [[wiki/02_Design/20261113_발신타깃_설계서_v1.0]]

## 현재 진행 (2026-11-14 13:15) — 후속 통합계획 v3.0 순차 진행
- **순번(W1~W5)**: ①W1 H5 좀비/중복(서버 정리 완료, 클라 `_join` 가드 유지) → ②W2 **P0 `CheckValidDimensions` 근본**(`flutter_webrtc 1.6.3` 네이티브 0-dim 가드 패치/업데이트) → ③W3 H5/F1/H6 실기 재검증 → ④W4 H1 서버 AMI 영상소스 보장 연계 확인 → ⑤W5 릴리스·origin 동기화·모니터링.
- **완화 현황**: `991139f`(muted/비활성 원격 트랙 제외·정리, 중복 join 가드) 반영, v0.0.24+24 유지. **P0 근본 미해결**(네이티브).
- **문서**: [[wiki/01_Projects/20261114_후속작업_통합계획서_v3.0]], [[wiki/07_Logs/작업로그_20261114]], `docs/_작업이력/2026-11-14.md`.
- **전제/차단**: NAS(dev/prd) 미접속→origin 기준. W2 빌드/패치 검증, W3 다단말·1201 실기 필요. 서버 H1은 승인/AMI 필요.

## 이전 진행 (2026-11-13 02:00, 요약) — F1/F2/G3 구현·v0.0.24
- F1 `_pendingCallTarget`, F2 A4 롤백, G3 `enable_events=yes` 반영(v0.0.24 build 24, sha256 `c8c6e4a7…`). ADR-008/D1·ADR-009/F2 실기 확인, G3 부분검증. 잔여: P0 크래시, H1/H5/F1/H6 재검증. 상세: [[wiki/06_Reports/20261113_F1F2G3_구현완료보고서_v1.0]], [[docs/보고서/20261113_후속작업계획서_v2.0]], [[wiki/07_Logs/작업로그_20261113]]

## 참조 문서
- [[docs/작업지도]] — Knowledge OS v3.0 Kernel
- [[wiki/01_Projects/client-project-plan]] — 클라이언트 프로젝트 계획
- [[wiki/02_Design/macOS-client-design]] — macOS 클라이언트 설계
- [[wiki/01_Projects/client-development-tasks]] — 작업 계획 및 마일스톤
- [[wiki/01_Projects/20261112_통화품질개선_작업계획서_v1.0]] — C→A→D→B WBS
- [[wiki/02_Design/sip-client-design]] — SIP Client 설계
- [[wiki/02_Design/20261112_통화품질_진단설계서_v1.0]] — L1~L7 진단 설계
- [[wiki/05_Decisions/ADR-004]] — SIP 엔진 sip_ua 교체 결정 기록
- [[wiki/05_Decisions/ADR-002]] — 초기 결정 기록
- [[wiki/05_Decisions/ADR-006-카메라없는단말_영상수신전용]] — recvonly 결정
- [[wiki/05_Decisions/ADR-008-re-INVITE_recvonly_유지]] — 재협상 옵션 유지(실기 검증 완료)
- [[wiki/05_Decisions/ADR-009-A4_재등록_롤백]] — A4 롤백(실기 검증 완료)
- [[wiki/06_Reports/20261113_영상없는참가자_식별처리_분석_v1.0]] — 영상 없는 참가자 식별 단절·H1~H6, 1:1 즉시 종료 2원인
- [[wiki/08_Experiments/20261113_1대1_즉시종료_교차검증_v1.0]] — 1101 v0.0.24 실기 KST↔UTC 교차검증
- [[docs/보고서/20261113_후속작업계획서_v2.0.md]] — v2.0 후속(W0~W4, H1~H6)·NAS(dev/prd) 배포 제외 정책
- [[wiki/01_Projects/20261114_후속작업_통합계획서_v3.0.md]] — 2026-11-14 통합계획(W1~W5)
- [[wiki/07_Logs/작업로그_20261114.md]] — 2026-11-14 로그
- [[wiki/07_Logs/작업로그_20261113.md]] — 2026-11-13 로그
- [[wiki/06_Reports/20261113_v0.0.24_앱크래시_교차검증보고서_v1.0.md]] — 1102/1103 WebRTC `CheckValidDimensions` fatal 크래시·서버 로그 공백 교차검증
