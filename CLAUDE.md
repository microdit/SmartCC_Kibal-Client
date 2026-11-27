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
| `origin` | 레거시 GitHub(전환 기간) | `https://github.com/microdit/SmartCC_Kibal-Client.git` |
| `dev-gh` | DEV GitHub(생성 시) | `https://github.com/microdit/Smart_Kibal-Client-DEV.git` |
| `test-gh` | TEST GitHub(생성 시) | `https://github.com/microdit/Smart_Kibal-Client-TEST.git` |
| `prd-gh` | PRD GitHub(생성 시) | `https://github.com/microdit/Smart_Kibal-Client-PRD.git` |
| `external-gh` | EXTERNAL GitHub(생성 시) | `https://github.com/microdit/Smart_Kibal-Client-EXTERNAL.git` |
| `dev` | 레거시 NAS DEV | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client.git` |
| `prd` | 레거시 NAS PRD | `ssh://atom@nas2:4949/.../SmartCC_Kibal-Client_prd.git` |

- **2026-11-26 영속 규약**: Server 4환경 분리와 쌍 관리. 검수 전 변경은 TEST(`test/<topic>` 또는 `test-gh`)에만 커밋/푸시. 검수 PASS 증거(analyze/test/DMG/SHA256/실기 로그) 후 DEV 승격. PRD/EXTERNAL은 승인 후 승격.
- **버전 사고 방지**: `git fetch --all --prune` 후 remote/tag 최신 확인. 선행 커밋 보존 + 버전 상향, 역행 덮어쓰기 금지. `git add -A` 금지.
- 상세: `wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md`, Server `SmartCC_Kibal/wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md` 참조.

> **2026-11-11 네트워크 참고**: 서버 MacPro가 유선 `192.168.0.3`(192.168.0.0/24)으로 전환됨. PRD 시놀로지 NAS(`nas2`=192.168.11.2)는 이 대역에서 **접근 경로 없음** → `dev`/`prd` push·PRD 배포 불가, GitHub만 동기화. `git-sync.sh`는 미도달 원격을 SKIP. DEV 배포는 로컬 Docker(`deploy/dev/up.sh`).

> **2026-11-19 네트워크 토폴로지 정정**: IPTime2(`192.168.0.1`)는 폐기. **IPTime1(공인 IP) + L2 스위치 단일 대역 `192.168.11.0/24`** 사용. Mac Pro 서버 `192.168.11.5`(Asterisk/OPS), PRD NAS `nas2` `192.168.11.3`. 기존 `192.168.0.3`/`192.168.11.39`/`192.168.11.2` 기록은 과거 대역. 외부망 포트포워딩은 IPTime1에서 `192.168.11.5`로 **단일 적용**(WSS 8089/TCP, RTP 10000-10200/UDP), DDNS `appletreeda.synology.me`용 인증서는 Synology에 이미 발급됨. 상세: `wiki/06_Reports/20261119_외부망검토의견서_v1.0.md`.

> **2026-11-09 동기화 참고**: SSH(`nas2` → `192.168.11.2:4949`) 자체는 키 인증으로 접속되나, `dev`/`prd` URL의 `/var/services/homes/atom/gitRepo/...` 경로가 존재하지 않거나 권한 문제로 Push 불가. NAS의 실제 Git 저장소 경로를 확인 후 remote URL을 갱신해야 한다. GitHub(`origin`)는 정상 동기화됨.

---

## 상태 (2026-11-27 업데이트)

- **4환경 분리 쌍 관리(영속)**: Server 규약과 동일하게 검수 전 TEST, PASS 후 DEV, 승인 후 PRD/EXTERNAL. 상세 `wiki/03_Guides/20261126_4환경_Git_운영규약_v1.0.md`.
- **Server-Client 교차 문서 동기화(영속)**: 양쪽 영향 사항은 Server `SmartCC_Kibal/wiki/07_Logs/YYYYMMDD_Server-Client_교차진행로그.md`와 Client `wiki/07_Logs/YYYYMMDD_Server-Client_교차진행로그.md`에 같은 날짜로 기록. 상세는 해당 repo, 상대 repo는 요약+경로+커밋 해시.
- **버전 사고 방지**: fetch/prune 후 선행 확인, 선행 보존+버전 상향, 역행 덮어쓰기/무검수 DEV·PRD 승격 금지.

## 상태 (2026-11-09)

- **macOS Client M1~M6 완료** (`feature/macOS-version`, `macos-client/`)
  - macOS desktop 스캐폴/권한/GoRouter UI, 린트 0건, Debug·Release 빌드 성공
  - SIP 엔진 교체: `flutter_sip`(Android 전용) → `sip_ua` + `flutter_webrtc 1.6.3` (ADR-004)
  - DEV Asterisk 실검증: REGISTER_OK / 1:1 CALL_OK / ConfBridge 3자 CONFERENCE_OK
  - 검증 도구: `macos-client/tool/{register,call,conference}_probe.dart`
- **문서**: `docs/보고서/20261109_macOS테스트결과보고서_v1.0.md`, `wiki/06_Reports/20261109_macOS_M1-M6_개발완료보고서.md`
- **후속**: MacBook 영상 실기 검증 → `wiki/04_Prompts/20261109_macbook_agent_후속작업프롬프트.md`
- **Web Client 완료**, **iOS/Windows/Android는 macOS 검증 구조 이식 예정**

## 상태 (2026-11-11)

- **원격 오디오 H1 해결**: `sip_ua` 원격 트랙 폐기 우회(`sip_client.dart`), `recovered=true kind=audio` 확인
- **미디어 경로 H4**: Release 엔타이틀먼트(`network.server`), `dtls_verify=fingerprint`, `media_address=192.168.11.39` 적용
- **Docker ICE 후보 보정**: `macos-client/packages/sip_ua` 로컬 포크(ADR-005), 172.16/12 후보 → `c=` 보정
- **H5 re-INVITE 미응답 수정**: `sip_client.dart` `onNewReinvite` 자동 수락. 영상/다자간 15~17초 ICE 실패의 직접 원인
- **MediaManager 다중 영상 수정(v0.0.9~11)**: 트랙별 렌더 스트림, 렌더러 notify, 최신 3타일 제한, 선택 UI
- **v1.5 실기(v0.0.8)**: H5 성공(`accepted=true`, `videoBytes` 증가, ICE 실패 0, 2분+ 유지)
- **v1.6 실기(v0.0.10, 3자)**: H5/ICE 안정. stale 트랙 누적/타일 폭주 → v0.0.11에서 최신 3타일+선택 UI
- **v0.0.11+11**: 참가자 영상 타일 선택/라벨/준비중 표시. **참가자 식별·1101 오디오 출력·3자 재검증 잔여**
- **v0.0.12+12 클라이언트 로그 자동 수집**: `RemoteLogForwarder`가 로그를 OPS(`POST /api/client-logs`, X-Client-Key)로 배출. 에이전트 조회 `scripts/ops_client_logs.sh`(list/tail/grep/follow), OPS 웹 "클라이언트 로그" 탭
- **v0.0.13+13 업로더 v2**: 앱 메뉴 "로그 전송 설정"에서 모드 선택(끄기/오류만/INFO/이벤트/INFO+이벤트/DEBUG/전체/사용자 지정), app.log offset 재전송으로 유실 0
- **v0.0.14+14 다자간 버그 수정**: 6000 회의 카드형 참가자 선택 화면, 수신 수락 크래시 2건, 유효 트랙 정리, 30초 미디어 요약 — 보고서 `docs/보고서/20261111_버그분석보고서_v1.0.md` / `20261111_버그수정완료보고서_v1.0.md`
- **v0.0.15+15 1:1 수정**: 수신측 영상 판정(단방향 영상), 갱신 타임아웃 통화 유지, 영상 30초 통계, 로그 중복 제거, OPS 서버 이벤트(`ops_client_logs.sh server`) — `docs/보고서/1vs1영상통화버그분석보고서_v1.2.md`. 서버 codec_opus 추가로 opus 우선 적용(WebRTC 엔드포인트)
- **서버 IP 변경 대응**: OPS `/api/client/config` + 로그인 화면 "서버 설정 갱신"(`server_config.dart`), 서버 `deploy/dev/update-server-ip.sh --check`/적용(수동 운영, launchd 감시는 ~/Downloads TCC로 미사용). 가이드: 서버 리포 `wiki/03_Guides/서버IP변경_자동갱신_가이드_20261111.md`
- **v0.0.16+16 (2026-11-12)**: 서버 유선 192.168.0.3 전환 후 **1:1·다자간 통화 성공**. 빌드/발행 `macos-client/scripts/release_macos.sh`(DMG Applications 링크 결함 수정)
- 상세: `wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0.md`
- **다음 과제(v0.0.17)**: 카메라 없는 1101도 참가자 영상 수신(recvonly) — 계획서 `wiki/01_Projects/20261112_음성전용참가자_영상수신_작업계획서_v1.0.md`, ADR-006
- 다음 세션: `wiki/04_Prompts/20261111_원격오디오_ICE_후속작업프롬프트_v1.0.md`

---

## 언어 정책 (영속)

- **특별한 지시가 없으면 모든 응답·문서·로그·커밋 메시지를 한국어로 작성한다.**
- 코드 식별자·라이브러리명·명령어·기술 표준 용어는 원문을 유지하고, 설명은 한국어로 한다.
- 사용자가 영어 등 다른 언어를 명시적으로 요청한 경우에만 해당 언어를 사용한다.

## 작업 시작 전 준수 지시서 읽기 (영속, 2026-11-27)

- **매 작업 시작 시 가장 먼저**: [[wiki/04_Prompts/20261127_작업시작전_준수지시서_읽기_규약_v1.0]]을 읽고 체크리스트를 수행한 뒤 착수한다.
- "진행해" 승인은 정책 준수 전제. 버전 임의 상향·feature 직접 커밋·승인 없는 force push 금지.
- 검수 전 산출물은 `test/*`에만, PASS 후 DEV 승격. `release_macos.sh` 가드(원격 최신 +1, TEST 브랜치 경고)를 무력화하지 말 것.

