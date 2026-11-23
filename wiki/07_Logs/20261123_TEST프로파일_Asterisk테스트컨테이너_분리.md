# 2026-11-23 TEST 프로파일 / Asterisk 테스트 컨테이너 분리

## 목적
- 기존 DEV/운영 설정 영향 없이 A10 1:1 등 실험을 수행.
- 클라이언트 프로파일에 TEST 추가, 서버 정보 변경 시 클라이언트 재발행 최소화 방향 정리.

## 환경 구분 (명심)
| 구분 | 용도 | Asterisk | 클라이언트 | 비고 |
|---|---|---|---|---|
| **DEV** | 개발 기본/통합 | `kibal-dev-asterisk` (5060/8088/8089, RTP 10000-10200) | DEV 프로파일 | 안정 기준선, 실험 직접 반영 금지 |
| **TEST** | 실험/재현 | `kibal-dev-asterisk-test` (15060/18088/18089, RTP 11000-11100) | TEST 프로파일 | 검증 전용, 깨져도 DEV 영향 없음 |
| **PRD** | 운영 NAS | `deploy/prd` compose | PRD 프로파일 | DEV/TEST 검증 후 단계적 반영 |

승격 단계: **TEST 실험/검증 → DEV 템플릿 반영 → DEV 통합 확인 → PRD 배포(PRD compose/운영 절차)**.

## 서버 (SmartCC_Kibal)
- DEV 안정 복구: `_1XXX` A10 1:1 ConfBridge 우회 실험 dialplan 제거, `#tryinclude "kibal_rooms_extensions.conf"` 위치 복구(6700 차단 부작용 수정), `dialplan reload`.
- TEST 컨테이너 추가: `deploy/dev/asterisk-test/compose.yaml`
  - 컨테이너: `kibal-dev-asterisk-test`, 프로젝트: `kibal-dev-asterisk-test`
  - 포트: 15060/udp(SIP), 18088/tcp(WS), 18089/tcp(WSS), 11000-11100/udp(RTP)
  - 설정: `deploy/dev/asterisk-test/config` (DEV config 복사본, 독립 수정)
- 실행:
  ```bash
  docker compose -f deploy/dev/asterisk-test/compose.yaml -p kibal-dev-asterisk-test up -d --build
  docker compose -f deploy/dev/asterisk-test/compose.yaml -p kibal-dev-asterisk-test down
  ```
- A10 실험 시: A10 SIP 서버 포트를 15060으로 향하게 하거나(장치 설정), 테스트 전용 내선/라우팅 사용. WebRTC 테스트 클라이언트는 TEST 프로파일(WS 18088) 사용.

## 클라이언트 (SmartCC_Kibal-Client)
- `ConnectionProfile`에 `test` 추가.
- TEST 기본값: `sipDomain=192.168.11.5, sipPort=15060, wsServer=ws://192.168.11.5:18088/ws, opsBaseUrl=http://192.168.11.5:8091`.
- 설정 UI 프로파일 선택에 TEST 노출(DEV/PRD/외부/TEST).
- `refreshSmart`는 TEST 선택 시 내부망 복귀에서 DEV로 강제 전환하지 않도록 보완.

## 서버 정보 config-driven 원칙 (요구사항)
- 목표: 서버 주소/포트 변경으로 클라이언트 DMG 재발행하지 않도록.
- 현 상태: 클라이언트는 OPS `/api/client/config`를 가져와 `ServerConfig` 갱신/저장(`refreshSmart/probeProfile`). 프로파일 기본값/후보는 Dart에 하드코딩.
- 다음 작업:
  1. OPS `/api/client/config` 또는 별도 `/api/client/profiles`에 프로파일별 bootstrap 후보/기본값 제공.
  2. 클라이언트는 하드코딩 기본값을 "최초 부트스트랩 fallback"으로만 사용, 성공한 OPS 응답의 프로파일 manifest를 캐시.
  3. TEST/DEV/PRD endpoint 변경은 OPS 설정/manifest 변경으로 전파.
  4. 릴리즈 채널 분리: `test`(사내 실험, 빠른 배포) / `dev`(개발 통합) / `prd`(운영). manifest의 `latest_version`, `min_supported_version`, `release_notes`를 채널별로 관리.

## 주의
- TEST Asterisk는 DEV OPS/DB를 공유하지 않도록 별도 네트워크/볼륨 사용. 현재 compose는 ops_audit 미마운트(실험용 단순화).
- TEST에서 검증된 dialplan만 DEV 템플릿(`server/asterisk/config`)에 반영하고 커밋.
- PRD 반영은 `deploy/prd` 절차/백업/롤백 확인 후 수행.
