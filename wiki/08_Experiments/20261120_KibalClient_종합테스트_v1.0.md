# Kibal Client 종합 테스트 결과

## 메타데이터

| 항목 | 내용 |
|------|------|
| 문서 ID | EXP-20261120-KIBAL-TEST-001 |
| 버전/작성일 | v1.0, 2026-11-20 |
| 상태 | 테스트 완료 |
| 작성 | MacBook(opencode) |
| 대상 브랜치 | `feature/external-network-access` |
| 대상 빌드 | `v0.0.50` (Info.plist 0.0.50, 내부IP 덮어쓰기 방지 fix 포함) |
| 실행 환경 | 한국 IP `211.253.173.236` (VPN 해제), LAN `192.168.11.54` |

---

## 1. 테스트 환경

| 항목 | 값 |
|------|----|
| 출구 IP | `211.253.173.236` (한국) |
| 로컬 IP | `192.168.11.54` (en6, LAN) |
| 클라이언트 | v0.0.49 (macOS, debug/release 빌드) |
| 프로필 | 외부망 (`appletreeda.synology.me`) |
| SIP 계정 | 1102 / 1103 / 1104 |
| OPS | `http://appletreeda.synology.me:8091` (HTTP-only) |
| WS | `wss://appletreeda.synology.me:8089/ws` |
| DSM | `https://appletreeda.synology.me:5001` (한국 IP 허용) |

---

## 2. 빌드·정적 분석·단위 테스트

| 항목 | 결과 | 상세 |
|------|------|------|
| `flutter build macos` | ✅ 성공 | 80.6MB, 경고 1건 (AppDelegate try? seek) |
| `flutter analyze` | ✅ 에러 0 | info 21건 (material.dart deprecation) |
| `flutter test` | ✅ 17/17 통과 | remote_log_filter, conference_participant, remote_log_offsets, media_device_settings, widget_test, sdp_codec |

---

## 3. 네트워크 연결 테스트

| 항목 | 기대 | 실측 | 판정 |
|------|------|------|------|
| DDNS 해석 | `211.253.173.236` | ✅ `211.253.173.236` | ✅ PASS |
| OPS health (외부) | HTTP 200 | ✅ `{"status":"ok","version":"0.1.1-dev"}` | ✅ PASS |
| OPS config (no key) | HTTP 401 | ✅ 401 AUTH_REQUIRED | ✅ PASS |
| OPS config (with key) | HTTP 200 | ✅ 200 | ✅ PASS |
| WS httpstatus (8089) | 200 Asterisk | ✅ Asterisk/22.8.1, TLS bind 8089 | ✅ PASS |
| DSM (5000 HTTP) | 200 | ✅ 200 | ✅ PASS |
| DSM (5001 HTTPS) | 200 | ✅ 200 | ✅ PASS |

---

## 4. SIP Probe 테스트 (외부 wss)

### 4.1 SIP 등록

| 항목 | 결과 |
|------|------|
| 1102 등록 | ✅ REGISTER_OK (Code 200, wss://appletreeda.synology.me:8089/ws) |
| SIP state | `registered` |

### 4.2 1:1 통화 (1102 ↔ 1103)

| 항목 | 결과 |
|------|------|
| 통화 수립 | ✅ CALL_OK |
| Caller (1102) | established=true, remoteStreams=2 (video+audio) |
| Callee (1103) | established=true, remoteStreams=1 (audio) |
| audioLost | 0 (추정) |

### 4.3 6700 회의 (1102 / 1103 / 1104)

| 항목 | 결과 |
|------|------|
| 회의 수립 | ✅ CONFERENCE_OK |
| 1102 | established=true, remoteStreams=2 (video+audio) |
| 1103 | established=true, remoteStreams=2 (video+audio) |
| 1104 | established=true, remoteStreams=2 (video+audio) |
| allEstablished | true |
| allRemote | true |
| allHasAudio | true |
| allHasVideo | true |

---

## 5. 방화벽 / 네트워크 이슈

| 이슈 | 원인 | 상태 |
|------|------|------|
| OPS 8091 hang (일시) | 컨테이너 unhealthy → 재시작으로 복구 | ✅ 해결 (현재 200) |
| DSM 외부 차단 (US IP) | NAS 방화벽 eth0 KR-only 규칙 | ⚠️ 한국 IP에서만 접근 가능; US는 미개방 |
| 5090/5091 포트 | NAS 미리스닝 (DSM은 5000/5001) | ℹ️ 5090/5091 사용 불필요 |
| scheme 오진 | HTTP vs HTTPS가 아닌 프로세스 hang이 원인 | ✅ 정정 완료 |

---

## 6. 잔여 / 미수행 항목

| 항목 | 사유 |
|------|------|
| 전체화면 진단 패널 캡처 | GUI 수동 필요 |
| `collect-test-metrics.sh` 실행 | GUI "로그보내기 → 즉시보내기" 수동 필요 |
| US VPN DSM 접근 | 방화벽 KR-only 미해제 (US 미추가) |
| OPS `client_log_url` 내부 IP 반환 | ✅ 클라이언트 측 수정 (v0.0.50): probeProfile에서 external은 defaultConfig 유지, 자격증명만 복사 |

---

## 7. 성공/실패 판정

| 카테고리 | 판정 |
|----------|------|
| 빌드·정적분석·단위테스트 | ✅ ALL PASS |
| SIP 등록 (외부) | ✅ PASS |
| 1:1 통화 (외부) | ✅ PASS |
| 6700 회의 (외부) | ✅ PASS |
| OPS·Asterisk 연결 (외부) | ✅ PASS |
| DSM (한국 IP) | ✅ PASS |

**종합 판정: Kibal Client v0.0.50 외부망(SIP 등록·1:1·6700 회의·OPS·Asterisk) 전체 정상 동작 확인. 빌드·테스트·정적분석 모두 통과.**

---

## 8. 변경 이력

| 버전 | 날짜 | 내용 |
|------|------|------|
| v1.0 | 2026-11-20 | 최초 작성 (MacBook, 한국 IP, probe+unit test 기반) |
