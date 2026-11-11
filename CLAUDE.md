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

> **2026-11-09 동기화 참고**: SSH(`nas2` → `192.168.11.2:4949`) 자체는 키 인증으로 접속되나, `dev`/`prd` URL의 `/var/services/homes/atom/gitRepo/...` 경로가 존재하지 않거나 권한 문제로 Push 불가. NAS의 실제 Git 저장소 경로를 확인 후 remote URL을 갱신해야 한다. GitHub(`origin`)는 정상 동기화됨.

---

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
- **v0.0.15+15 1:1 수정**: 수신측 영상 판정(단방향 영상), 갱신 타임아웃 통화 유지, 영상 30초 통계, 로그 중복 제거, OPS 서버 이벤트(`ops_client_logs.sh server`) — `docs/보고서/1vs1영상통화버그분석보고서_v1.2.md`. opus 우선은 codec_opus 부재로 보류
- 상세: `wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0.md`
- 다음 세션: `wiki/04_Prompts/20261111_원격오디오_ICE_후속작업프롬프트_v1.0.md`
