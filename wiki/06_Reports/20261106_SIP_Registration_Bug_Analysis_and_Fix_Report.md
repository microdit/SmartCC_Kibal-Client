# SIP Registration Bug Analysis and Fix Report

**Report Date**: 2026-11-06
**Report Type**: SIP Registration Bug Analysis & Fix
**Component**: Web Client SIP Registration / Asterisk PJSIP Configuration
**Related Issues**: CT01/CT02 PoC Verification

## 1. Bug Analysis

### 1.1 Symptoms
- Web Client에서 `1101`/`1102` 번호로 SIP 등록 시도 시 `미등록` 상태 표시
- 콘솔 로그에 `status code 500` (1101) 및 `status code 401` (1102) 반복 발생
- WebSocket 연결은 성공하지만 등록 실패

## 1.2 Root Cause Analysis

### 1.2.1 Bug 1: Status Code 500 (1101)
- **원인**: `/opt/kibal/config/pjsip.conf.template` 템플릿 파일에 `${SIP_PASSWORD_1101}` placeholder가 남아 있어, 컨테이너 재시작 시 MD5 해시 값으로 재생성됨
- Asterisk running config(`/run/asterisk/pjsip.conf`)는 일시적 수정 가능으나 영구 적용 어려움
- **영향도**: 등록이 영구적으로 적용되지 않아 지속적인 재등록 시도 필요

### 1.2.2 Bug 2: Status Code 401 (1102)
- **원인**: Docker 환경 변수 `SIP_PASSWORD_1102`가 여전히 **MD5 해시** 값(`3ab8f8012caee1cbab300ded5840ea6d`) 보유
- Asterix는 plain text(`1102pass`)를 expecting하지만, client가 MD5 해시 전송하여 인증 실패
- **부가 원인**: 1102 로그에 `192.168.11.2`로 연결 기록되지만 서버는 `192.168.11.39`에 있음 (네트워크 불일치)
- **영향도**: 인증 지속 실패, 등록 영구 불가능

### 1.2.3 Bug 3: Setting Persistence Issue
- **원인**: 컨테이너 재시작 시 다음 초기화됨
  - `/opt/kibal/config/pjsip.conf.template` → MD5 해시로 재생성
  - `SIP_PASSWORD_1101`~`SIP_PASSWORD_1104` env vars 초기화
  - `/run/asterisk/pjsip.conf` 설정 초기화
- **원인**: entrypoint 스크립트(`/usr/local/bin/kibal-entrypoint`)가 template 파일과 env vars를 기본값으로 재생성
- **영향도**: 설정이 재시작마다 초기화되어 지속적인 수정 필요

## 2. Bug Fix Report

### 2.1 Completed Fixes

#### Fix 1: `/web/.env` 파일 생성 (완료)
- **경로**: `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client/web/.env`
- **내용**:
  ```
  VITE_SIP_DOMAIN=192.168.11.39
  VITE_SIP_WS_PORT=8088
  VITE_SIP_WS_SERVER=ws://192.168.11.39:8088/ws
  VITE_SIP_USERNAME=1101
  VITE_SIP_PASSWORD=1101pass
  VITE_SIP_DISPLAY_NAME=Kibal Web
  ```
- **효과**: Web Client가 올바른 SIP 설정으로 로드됨

#### Fix 2: Asterisk running config 수정 (완료)
- **대상**: `/run/asterisk/pjsip.conf` (running container)
- **변경사항**: MD5 해시 → plain text 비밀번호(`1101pass`~`1104pass`) 변경
- **확인**: `grep '1101pass' /run/asterisk/pjsip.conf` → `1101pass` 확인됨
- **한계**: 컨테이너 재시작 시 초기화됨 (template 파일 permanent 수정 필요)

#### Fix 3: Workaround (일시적)
- **방법**: `docker exec 9c9829137d5e sh -c 'envsubst ${SIP_PASSWORD_1101} ${SIP_PASSWORD_1102} ${SIP_PASSWORD_1103} ${SIP_PASSWORD_1104} < /opt/kibal/config/pjsip.conf.template > /run/asterisk/pjsip.conf'`
- **효과**: 현재 세션에서 pjsip.conf 재생성 (재시작 시 초기화됨)

### 2.2 Pending Fixes

#### Fix 4: Template File Permanent 수정 (보류)
- **대상**: `/opt/kibal/config/pjsip.conf.template`
- **변경사항**: `${SIP_PASSWORD_1101}` → `1101pass`, `${SIP_PASSWORD_1102}` → `1102pass`, `${SIP_PASSWORD_1103}` → `1103pass`, `${SIP_PASSWORD_1104}` → `1104pass`
- **방법**: Python 스크립트 파일 생성 후 실행 (shell escaping 이슈로 보류)
- **필요성**: 컨테이너 재시작 후 설정 유지 보장

#### Fix 5: Docker env vars permanent 고정 (보류)
- **대상**: `SIP_PASSWORD_1101`~`SIP_PASSWORD_1104`
- **현재 값**: MD5 해시 값 (`21b570670b1eec59ad5b90b76ee3a03b` 등)
- **변경 필요**: `1101pass`~`1104pass`로 permanent 변경
- **방법**: 
  - `docker commit`으로 컨테이너 상태 저장 후 재시작
  - 또는 `/usr/local/bin/kibal-entrypoint` 스크립트 수정
  - 또는 `docker run` 시 `--env` 플래그 사용 시 영구 유지 확인 필요

#### Fix 6: 1102 연결 IP 불일치 해결 (보류)
- **증상**: 로그에 `192.168.11.2`로 연결 기록되나 서버는 `192.168.11.39`에 있음
- **원인**: 네트워크 설정 또는 라우팅 문제
- **영향도**: 1102 등록 시 인증 실패 및 연결 이상
- **조치**: 네트워크 설정 검토 및 수정 필요

## 3. Test Procedure (Document-Followed)

### CT01: SIP Registration Test (another MacBook)
1. `http://192.168.11.39:5173` 접속
2. 설정:
   - 서버 도메인: `192.168.11.39`
   - WebSocket: `ws://192.168.11.39:8088/ws`
   - 내선: `1101`
   - 비밀번호: `1101pass`
3. "등록" 버튼 클릭
4. 기대 결과: "등록됨" 표시 ✅

### CT02: 1:1 Video Call Test
1. 클라이언트 1(이 Mac): `1101`으로 등록
2. 클라이언트 2(another MacBook): `1102`으로 등록
3. 클라이언트 1에서 `1102` 호출
4. 클라이언트 2에서 "받기"
5. 기대 결과: 양쪽 비디오 화면 ✅

## 4. Bug Status Table

| Bug ID | Priority | Current Status | Fix Applied | Remaining Action |
|--------|----------|---------------|-------------|-----------------|
| Bug 1 (500 error 1101) | High | Partially Fixed | `/web/.env` 생성, running config 수정 | Template permanent 수정 필요 |
| Bug 2 (401 error 1102) | High | Partially Fixed | env vars set in running container | Docker env vars permanent 고정, IP 불일치 해결 |
| Bug 3 (설정 영구성) | High | Not Fixed | - | template 파일 permanent 수정 필요 |
| Bug 4 (env vars permanent) | High | Not Fixed | - | env vars permanent 고정 필요 |
| Bug 5 (IP 불일치 1102) | Medium | Not Fixed | - | 네트워크 설정 검토 및 수정 |

## 5. Next Steps

1. **우선시**: another MacBook에서 Web Client UI 테스트 (CT01/CT02)
   - 현재 적용된 설정이 UI에서 작동하는지 확인
   - 성공 시 CT02 통화 테스트 진행

2. **중요**: template 파일 permanent 수정 (`/opt/kibal/config/pjsip.conf.template`)
   - Python 스크립트 또는 다른 방법으로 permanent 수정
   - 컨테이너 재시작 후 설정 유지 보장

3. **중요**: Docker env vars permanent 고정 (`SIP_PASSWORD_1101`~`SIP_PASSWORD_1104`)
   - `docker commit` 또는 entrypoint 스크립트 수정
   - 재시작 후 설정 유지 보장

4. **중요**: 1102 연결 IP 불일치 해결 (`192.168.11.2` → `192.168.11.39`)
   - 네트워크 설정 검토 및 수정

## 6. Related Documents

- [[wiki/01_Projects/client-project-plan]] - 프로젝트 계획서
- [[wiki/02_Design/architecture]] - 시스템 아키텍처
- [[wiki/07_Logs/작업로그_20261106.md]] - 작업 로그
- [[wiki/01_Projects/client-project-plan.md]] - 프로젝트 계획서 상세
- [[wiki/01_Projects/client-development-tasks.md]] - 개발 작업 항목
- [[wiki/02_Design/web-client.md]] - 웹 클라이언트 가이드
- [[wiki/03_Guides/development-guide.md]] - 개발 가이드
- [[wiki/05_Decisions/ADR-001]] - 결정 기록

## 7. Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| v1.0 | 2026-11-06 | microdit | Initial bug analysis and fix report creation |
