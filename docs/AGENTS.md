# AGENTS.md — Agent Memory v3.0

## 프로젝트 정의
- **프로젝트명**: SmartCC_Kibal-Client (멀티플랫폼 SIP 영상통화 클라이언트)
- **목적**: Asterisk 22 LTS 서버(`SmartCC_Kibal`)와 연동하는 Web (React + SIP.js) + macOS/모바일 (Flutter) 클라이언트 개발
- **버전**: Knowledge OS v3.0 (2026-10-29)
- **별도 리포지토리**: `git@github.com:microdit/SmartCC_Kibal-Client.git`

## 환경
| 구분 | 경로/IP | 비고 |
|------|---------|------|
| DEV (SIP 서버) | `192.168.11.5` | **2026-11-19 토폴로지 정정**: Mac Pro. IPTime1 + L2 스위치 단일 대역 `192.168.11.x` (구 `192.168.0.3`/`192.168.11.39` 폐기). Docker: `kibal-dev-asterisk`(dev), `kibal-dev-ops`(ops) |
| Client workspace | `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client` | macOS |
| PRD NAS (`nas2`) | `192.168.11.3` | 2026-11-19 확인 (구 `192.168.11.2`). Git dev/prd remote, Synology DDNS+인증서(`appletreeda.synology.me`) 보유 |
| 외부 접근 (계획) | SIP **WSS 8089/TCP** / RTP 10000-10200/UDP → `192.168.11.5` | **단일 NAT**: IPTime1에서만 포트포워딩. OPS 8091·UDP 5060 미개방. DDNS 인증서는 Synology에 이미 발급됨. 상세 [[wiki/06_Reports/20261119_외부망검토의견서_v1.0]] (구 이중 NAT 가이드 `docs/보고서/20261114_...`는 폐기) |
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
- **순번(W1~W5)**: ①W1 H5 좀비/중복(서버 정리 완료, 클라 가드 유지) → ②W2 **P0 `CheckValidDimensions` 근본**(진행) → ③W3 H5/F1/H6 실기 재검증 → ④W4 H1 서버 AMI 영상소스 보장 연계 확인 → ⑤W5 릴리스·origin 동기화·모니터링.
- **W2 진행(패치·빌드 완료)**: `packages/flutter_webrtc`(1.6.3 포크, darwin 0-dim/무효 프레임 가드·픽셀버퍼 리사이즈) + `dependency_overrides`. `pub get`/`test` 17/17, debug·release 빌드 성공(Release app 76M, SHA256 `c24dfa4…9832`, v0.0.24+24). 실기 배포/크래시 재현 검증 미수행.
- **문서**: [[wiki/01_Projects/20261114_후속작업_통합계획서_v3.0]], [[wiki/07_Logs/작업로그_20261114]], `docs/_작업이력/2026-11-14.md`.
- **W3 배포준비**: 릴리스 DMG `~/Downloads/macos_client_v0.0.24+24_w2.dmg`(37M, sha256 `4c5caa3d…c63a`) 생성, 현황 [[wiki/08_Experiments/20261114_W3_실기재검증_배포준비_v1.0]].
- **전제/차단**: NAS(dev/prd) 미접속→origin 기준. W3 실기(다단말·1201, 활성통화 종료 후) 필요. 서버 H1은 승인/AMI 필요.

## 현재 진행 (2026-11-17) — v0.0.29 릴리스 파이프라인 수정 · 3-way 동기화
- **v0.0.29 릴리스 완료**: `release_macos.sh --no-bump`이 step 4 `flutter analyze` info 1건으로 중단(`login_screen.dart:474` `${min}` → `$min` 수정, analyze No issues found) → **v0.0.29 (build 29) 발행 완료** (DMG `macos_client_v0.0.29.dmg`, sha256 `15a745f7…`, Info.plist 0.0.29, adhoc 서명). 직접 빌드(`build_macos.sh release`)도 성공.
- **3-way 동기화 복구**: NAS(nas2:4949) 접속 가능 확인(2026-11-11 대역·2026-11-09 경로 이슈와 상이). dev/prd push 거절(원격 v0.0.30 커밋) → 병합(`551491ac`) → push OK → github도 거절(`c34d99fe`, dev/prd 커밋과 동일 내용·트리 동일) → 병합(`63855561`) → **github/dev/prd 모두 0/0 in sync**, working tree clean.
- **v0.0.30 병합**: 회의실 지정번호 자동입장(`/conference` extra 전달, SIP 등록 시 자동 `_join`, 미등록 시 주소록 유지+안내), pubspec 0.0.30+30.
- **문서**: [[docs/보고서/20261117_버그원인분석보고서_v1.0]], [[docs/보고서/20261117_버그수정완료보고서_v1.0]], [[wiki/06_Reports/20261117_macos_릴리스_파이프라인_버그분석_v1.0]], [[wiki/07_Logs/작업로그_20261117]]
- **벡터DB 재색인**: `venv_client/bin/python scripts/index_wiki.py --reindex` → **117 files, 1113 chunks** (collection `kibal_client_wiki`).
- **Git**: `./scripts/git-sync.sh --auto --no-deploy` → `fd86abf1`, `7ae1fb99`, `63855561`. PRD 배포는 여전히 미수행(`--no-deploy`).
- **잔여**: v0.0.30 회의실 자동입장 실기 검증, NAS 경로(2026-11-09/11 이전) 문서 정합성 후속.

## 현재 진행 (2026-11-19) — 외부망 기술검토
- 외부망 접근 기술검토 의견서 작성: [[wiki/06_Reports/20261119_외부망검토의견서_v1.0]]
- **토폴로지 정정**: IPTime2 폐기 → IPTime1 + L2 스위치 단일 대역 `192.168.11.x`. Mac Pro `192.168.11.5`, NAS `nas2` `192.168.11.3`.
- 결정: 기존 DDNS(`appletreeda.synology.me`) 재사용, OPS 8091/UDP 5060 미개방, **WSS/TLS 우선**, iPad 검토는 별도 문서. **DDNS 도메인용 인증서는 Synology에 이미 발급 존재**.
- 포트 요청: **TCP 8089(WSS)** + **UDP 10000-10200(RTP)** 를 **IPTime1 한 곳**에서 `192.168.11.5`로 포트포워딩(8088은 내부 전용). 이중 포트포워딩 불필요.
- 서버 주의: ws/wss 전송은 transport `external_*` 무시 → endpoint `media_address=<공인 IP>` 필요, SDP `c=`에는 DDNS 호스트명 불가.
- 미확인: 공인 IP 동적 갱신 시 SDP `c=` 반영 방식, IPTime1 접근/테더링 실기 검증 시간, Synology 인증서 내보내기 경로.
- 의견서 v1.2: DEV/PRD/외부 서버 환경별 대비책(프로필 기반 OPS config, 공인 IP↔SDP 분리, 인증서/포트/RTP 범위 분리, TURN/VPS fallback) 추가. PRD `MEDIA_ADDRESS=CHANGE_ME_PUBLIC_IP` placeholder는 미해소 리스크.
- **전용 브랜치**: `feature/external-network-access` 생성. 작업계획서 [[wiki/01_Projects/20261119_외부망접근_작업계획서_v1.0]] (W1~W10), 로그 [[wiki/07_Logs/20261119]] 섹션 3. 포트: IPTime1 → `192.168.11.5` 8089/TCP + 10000-10200/UDP.
- **구현 완료(코드)**: 서버 `http.conf.template`/`entrypoint.sh`(조건부 transport-wss·인증서 검사·`SDP_MEDIA_ADDRESS`), DEV/PRD compose·env, 클라이언트 `ServerConfig.secure` + OPS `secure`→withScheme 자동 https/wss. analyze 0 / test 17/17.
- **실제 적용(2026-11-19)**: Synology DDNS 인증서(`CN=appletreeda.synology.me`, 만료 2026-12-31)를 `deploy/dev/certs/`에 배치, `.env` `TLS_ENABLE=yes`. HTTPS 8089·wss transport 확인, WSS REGISTER_OK. probe 3종 초기화 버그 수정. 6700 AI봇(7001) 재기동 후 1080p 송출 확인. 외부망 1103 인증 실패는 OPS 8091 미개방 → **오프라인 인증** + DDNS 저장 시 wss 자동전환 추가. **v0.0.38 빌드/발행**.
- **6700 품질 수정(v1.6)**: 공인 IP를 전역 `media_address`로 써서 내부 RTP가 NAT hairpin을 통과하며 1102 프리즈/1101 media stall 발생 → `SDP_MEDIA_ADDRESS=192.168.11.5` 복구, `rtp.conf`에 `stunaddr` + `ice_host_candidates`(Docker IP→LAN, include_local_address)로 내부/공인 이중 후보 구성. 1:1·3자·6700 프로브 재검증 OK.
- **v1.7 클라이언트 수정**: 클라이언트도 LAN이면 STUN을 쓰지 않아 SDP `c=`가 공인 IP가 되지 않도록 `AppConstants.iceServersFor()` 분리, 로그인 성공 시 `markLocalVerified()`로 외부 1103 로컬 인증, 설정 오프라인 인증 버튼 상시 노출. **v0.0.39 발행**(SHA256 `c4d05d88…`), analyze 0 / test 17/17. 잔여: v0.0.39 실기 재검증, 외부 단말 미디어, 인증서 갱신, PRD, TURN.
- **버그 보고서**: [[wiki/06_Reports/20261119_외부망WSS_6700품질_버그원인분석보고서_v1.0]], [[wiki/06_Reports/20261119_외부망WSS_6700품질_버그수정완료보고서_v1.0]] 작성. 봇 Chromium 재실행 수정 포함 서버/클라이언트 변경 검증 결과 기록.
- 클라이언트: 로그인 WSS hint 반영, `flutter analyze` 0 / `test` 17/17. 작업로그 [[docs/_작업이력/2026-11-19]]

## 현재 진행 (2026-11-20) — 슬립/재개 후 6700 복구
- 점검 정상: IP `192.168.11.5`, OPS health 200, SIP auth 12건 PASS, RTP/STUN/WSS 정상.
- 원인: 진단봇 데몬 2개 + 7001 ConfBridge 채널 2개/1106 잔류로 6700 영상 소스 중복.
- 조치: 데몬/채널 전부 정리 후 단일 봇 재기동(PID 4131), 1080p 송출 및 6700 `conference_probe` videoBytes 증가 확인.
- 봇 단일 인스턴스 보장 완료: 서버 `scripts/restart-diag-bot.sh`(`ensure|restart|status|stop`) + 데몬 PID lock/잔류 7001 채널 자동 hangup. launchd는 TCC 차단으로 제거하고 데몬 자체 복구로 확정. 사용 안내 [[wiki/03_Guides/20261120_진단봇_단일인스턴스_사용안내_v1.0]], 로그 [[wiki/07_Logs/20261120]]
- **v0.0.40**: v0.0.39 media stall 오검출(re-INVITE 시 카운터 감소) 및 재진입 경합 수정. `sip_client.dart` 재baseline, `sip_provider.dart` 스톨 플래그 초기화, `conference_screen.dart` connecting 중 입장 차단. analyze 0/test 17/17. 보고서 [[wiki/06_Reports/20261120_v0.0.39_6700재진입실패_버그분석_v1.0]]
- **v0.0.41**: 설정에 `로그보내기` 추가 — 자동보내기(즉시+5분 주기, `autoSend` 저장)와 즉시보내기(1회) 동시 사용 가능. `scripts/collect-test-metrics.sh`로 네트워크 전환 품질지표를 phase별 wiki 수집. 사용안내 [[wiki/03_Guides/20261120_로그보내기_및_품질지표수집_사용안내_v1.0]], SHA256 `e02eb552…`
- **v0.0.42**: 앱 내 품질지표 GUI 추가 — OPS 로그 기반 표+그래프(fps/vLost/freeze/pli), 양호·주의·위험 진단. `CustomPaint`만 사용해 외부 의존성 없음(1 source multi OS). SHA256 `0e8aeab8…`
- **v0.0.43**: 영상 품질 수동 설정 추가 — 320p/640p/720p/1080p/4K × 15/24/30/60fps 조합, `VideoQualitySettings` 저장, `setParameters`+트랙 교체 적용. 자동은 BALANCED 위임. SHA256 `64a528ac…`
- **v0.0.44**: 전체화면에 전송속도 진단 버튼/오버레이 추가 — 영상·음성·네트워크 실시간/60초 평균, 외부 의존성 없음. SHA256 `056e3e90…`
- **품질진단 문서**: [[wiki/01_Projects/20261120_클라이언트품질진단_기획서_v1.0]], [[wiki/02_Design/20261120_클라이언트품질진단_설계서_v1.0]], [[wiki/03_Guides/20261120_클라이언트품질진단_사용안내서_v1.0]], [[wiki/08_Experiments/20261120_클라이언트품질진단_자체검증_v1.0]] 작성. v0.0.41~44 기능/검증/이슈 정리.
- **외부망 테스트 절차서**: [[wiki/03_Guides/20261120_외부망접근_테스트절차서_v1.0]] — 도메인은 `appletreeda.synology.me`만 사용(`appletree`는 오답), WSS REGISTER_OK 사전 확인 완료.
- **v0.0.45 연결 프로필**: DEV/PRD/외부망 프로필 저장 + OPS `/api/client/config` 자동 탐색 적용, 실패 시 수동 입력. 사용안내 [[wiki/03_Guides/20261120_연결프로필_자동설정_사용안내_v1.0]], SHA256 `8fbf24e4…`
- **v0.0.46 크래시 수정**: flutter_webrtc 로컬 포크 `getSources:`를 메인 큐로 이동해 AVCaptureDevice 초기화 레이스 제거. 보고서 [[wiki/06_Reports/20261120_getSources_네이티브크래시_수정보고서_v1.0]], 후속과제 [[wiki/01_Projects/20261120_후속과제_정리_v1.0]]
- **릴리스 요약**: [[wiki/06_Reports/20261120_v0.0.41-46_릴리스요약_v1.0]] — v0.0.41~48 변경/커밋/SHA256/문서 색인. wiki 색인 재생성 완료.
- **v0.0.47~48**: 프로필 변경 시 로그 URL 연동, 프로필별 연결 테스트(OPS/WS/로그) 추가. 외부망 8091 차단은 정상이며 로그는 로컬 보관 후 재전송. 안내서 [[wiki/03_Guides/20261120_연결프로필_자동설정_사용안내_v1.0]], [[wiki/03_Guides/20261120_외부망접근_테스트절차서_v1.0]]
- **외부관점 테스트**: [[wiki/08_Experiments/20261120_외부망접근_외부관점_테스트_v1.0]] — DDNS 8089 HTTPS/WS PASS, 8091/8088 TIMEOUT(정책 차단). webfetch egress가 공인 IP와 동일해 해외 관점은 사용자 VPN 재확인 필요.
- **미국 VPN 로그 분석**: [[wiki/08_Experiments/20261120_미국VPN_외부망테스트_로그분석_v1.0]] — OPS 8091 차단(예상), 로그는 지연 재전송 후 서버 수신, OPS unhealthy 재시작 복구. SIP/통화 이벤트 없음 → 외부 통화 미검증.
- **OPS hang 진단 수령 검증**: [[wiki/06_Reports/20261120_OPS8091_hang_진단보고서_MacPro전달용_v1.0]] — 외부 OPS HTTP-only 정정, git-sync push 버그 수정 확인, 내부/외부 health 200 재검증. v0.0.49 SHA256 `fc5ae6db…`
- **자체 테스트 종합**: [[wiki/08_Experiments/20261120_에이전트_자체테스트_종합_v1.0]] — 빌드/외부관점/SIP·회의/로그/일일점검 결과 및 미수행 항목 정리.
- **MacBook 검증 지시**: [[wiki/04_Prompts/20261120_MacBook_외부망_종단간검증_작업지시_v1.0]] — 외부 프로필 종단간 검증 절차(연결 테스트·SIP·통화·진단·로그·보고). SHA 대신 Info.plist 버전 기준.
- **E2E 결과**: [[wiki/08_Experiments/20261120_외부망_종단간검증_v1.0]] — 미국 VPN에서 REGISTER/CALL/CONFERENCE OK. client_log_url 내부 IP 덮어쓰기 방지 v0.0.50 반영.
- **TURN Staging**: [[wiki/08_Experiments/20261120_TURN_coturn_Staging검증_v1.0]] — coturn 시간제 HMAC, 강제 RELAY 1:1/3자 OK. 운영 포트 개방·인증서 갱신·공인IP 동기화는 승인 대기. v0.0.53.
- **OPS hang 대응**: 서버 c9d4f75 — SQLite WAL·autoheal·진단 스크립트 적용, 60/60 동시요청 200. 클라이언트는 /api/client/config 인증 + HTTP 정규화(daa0a711)로 우회.
- **v0.0.54**: 로그 URL https→http 시작 시 강제 정규화. 23:00 1102 로그 미수신 원인(https URL) 제거.
- **v0.0.55**: 인증 실패 시 키/내선 보존, 서버 불통은 localVerified 유지, 200 ok 검증. 주소록/인증 소실 방지..

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
- [[wiki/08_Experiments/20261114_W3_실기재검증_배포준비_v1.0.md]] — W3 배포준비/현황
- [[wiki/07_Logs/작업로그_20261114.md]] — 2026-11-14 로그
- [[wiki/07_Logs/작업로그_20261113.md]] — 2026-11-13 로그
- [[wiki/06_Reports/20261113_v0.0.24_앱크래시_교차검증보고서_v1.0.md]] — 1102/1103 WebRTC `CheckValidDimensions` fatal 크래시·서버 로그 공백 교차검증

---

## 언어 정책 (영속)

- 특별한 지시가 없으면 **모든 응답·문서·로그·커밋 메시지를 한국어**로 작성한다.
- 코드 식별자·라이브러리명·명령어·기술 용어는 원문 유지, 설명은 한국어.
- 사용자가 다른 언어를 명시적으로 요청한 경우에만 해당 언어 사용.
