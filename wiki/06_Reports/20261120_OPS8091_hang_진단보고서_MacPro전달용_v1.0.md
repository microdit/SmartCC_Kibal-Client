# OPS 8091 서비스 hang 진단 보고서 (MacPro 서버 작업자 전달용)

| 항목 | 내용 |
|------|------|
| **문서 ID** | REPORT-20261120-OPS-HANG-001 |
| **작성일** | 2026-11-20 |
| **작성자** | SmartCC_Kibal-Client (macOS 클라이언트 측 AI 에이전트) |
| **대상** | SmartCC_Kibal 서버 (MacPro 192.168.11.5) AI 코딩 에이전트 |
| **브랜치** | `feature/external-network-access` (`328ca2ce`) |
| **클라이언트 버전** | `macos-client 0.0.48+48` |
| **관련** | [[wiki/03_Guides/20261120_외부망접근_테스트절차서_v1.0]], [[wiki/06_Reports/20261119_외부망검토의견서_v1.0]] |

---

## 1. 요약 (Executive Summary)

- **증상**: 클라이언트의 로그 전송(`POST /api/client-logs`) 및 "연결 테스트"가 실패한다. 사용자가 `http://211.253.173.236:8091/api/client-logs` 를 입력해도 동작하지 않는다.
- **근본 원인**: MacPro(192.168.11.5)의 OPS 서비스(`kibal-dev-ops`, 포트 8091)가 **hang/unresponsive** 상태. TCP 포트는 open이지만 HTTP 응답이 전혀 없다.
- **클라이언트 코드는 정상**: URL 생성·프로파일 연동·연결 테스트 로직 모두 정상 동작. 서버 OPS가 응답하지 않아 실패.
- **필요 조치**: MacPro에서 OPS 컨테이너 재시작. 클라이언트 측 SSH 접근 불가(키 미보유)로 서버 측 작업자에게 위임.

---

## 2. 진단 절차 및 결과

### 2.1 DNS / 포트 도달성

```bash
dig +short appletreeda.synology.me          # → 211.253.173.236
nc -zv -G 5 appletreeda.synology.me 8089    # succeeded (WSS)
nc -zv -G 5 appletreeda.synology.me 8091    # succeeded (OPS TCP open)
nc -zv -G 5 211.253.173.236 8091            # succeeded (외부 포트포워딩 동작)
```

- DDNS → 공인 IP 해석 정상.
- 8089 (WSS 시그널링): 외부 개방·TLS 정상 (HTTP 426 Upgrade Required 반환).
- 8091 (OPS): **TCP는 open이지만 HTTP 응답 없음** (외부·내부 모두 동일).

### 2.2 HTTP 응답 검증

```bash
curl -v --connect-timeout 5 --max-time 8 http://211.253.173.236:8091/api/client-logs
# → Connected, request sent, "Operation timed out after 8004 ms with 0 bytes received"

curl -v --connect-timeout 3 --max-time 4 http://192.168.11.5:8091/api/client-logs
# → HTTP 000 (timeout)
```

- 8091 포트는 TCP accept하지만 HTTP 응답이 0바이트. OPS 프로세스가 hang 또는 데드락 상태.

### 2.3 내부망 포트 스캔 (MacPro 192.168.11.5)

| 포트 | 상태 | 서비스 |
|------|------|--------|
| 8080 | refused | (미사용) |
| 8088 | open | Asterisk 22.8.1 (HTTP) |
| 8089 | open | Asterisk WSS (TLS) |
| 8090 | refused | (미사용) |
| 8091 | **open but hang** | **OPS (kibal-dev-ops) — 응답 없음** |
| 8092 | refused | (미사용) |
| 3000 | open | Next.js (SmartCodexStudio, 별개 서비스) |

### 2.4 NAS (192.168.11.2) 포트

| 포트 | 상태 | 서비스 |
|------|------|--------|
| 8088 | open | Asterisk 22.8.1 |
| 8090 | open | nginx 1.26.3 |
| 8091 | refused | OPS 없음 (MacPro에만 존재) |

- OPS는 MacPro(.5)에만 존재하며 현재 hang.

### 2.5 ops_client_logs.sh 실행 결과

```bash
OPS_URL=http://192.168.11.5:8091 ./scripts/ops_client_logs.sh list
# → JSON parse error: empty response (OPS down)
```

### 2.6 SSH 접근 시도 (클라이언트 측에서)

- `macpro` alias → 192.168.11.39 (구 IP, 도달 불가)
- `microdit`/`atom`/`admin`/`root` @ 192.168.11.5 → Permission denied (publickey)
- 사용 가능한 키: `~/.ssh/id_macpro`, `~/.ssh/id_ed25519`, `~/.ssh/nas2_ed25519` — MacPro 인증 실패
- **結論**: 클라이언트 측에서 MacPro SSH 접근 불가. 서버 측 작업자 개입 필요.

---

## 3. 클라이언트 측 정상 동작 확인

### 3.1 URL 생성 로직

- `AppConstants.opsLogUrl(domain)` → `http://$domain:8091/api/client-logs`
- 외부망 프로파일: `http://appletreeda.synology.me:8091/api/client-logs` (http — OPS는 HTTP only)
- DEV 프로파일: `http://192.168.11.5:8091/api/client-logs`
- PRD 프로파일: `http://192.168.11.3:8091/api/client-logs`

### 3.2 프로파일 전환 시 로그 서버 동기화 (v0.0.48)

`settings_screen.dart` `_switchProfile()` → `_applyLogUrl(cfg)` 호출:
```dart
void _applyLogUrl(ServerConfig cfg) {
  final s = RemoteLogForwarder.instance.settings;
  RemoteLogForwarder.instance.applySettings(RemoteLogSettings(
    mode: s.mode,
    url: cfg.clientLogUrl,   // 프로파일의 clientLogUrl로 갱신
    key: s.key,
    ...
    urlOverridden: true,     // 수동 지정으로 고정
    autoSend: s.autoSend,
  ));
}
```

- 프로파일 전환 시 로그 전송 URL이 함께 갱신됨 ✓
- `onLogin()`에서도 domain 기반으로 URL 갱신 (synology.me → https) ✓

### 3.3 연결 테스트 (`testConnection`)

- `_post(lines: [])` → 빈 POST 전송. 서버 2xx 응답 시 성공.
- 현재 서버 hang으로 인해 실패. 서버 복구 후 정상 동작 예상.

---

## 4. 사용자 보고 사항 대조

| 사용자 입력 | 결과 | 원인 |
|-------------|------|------|
| `http://211.253.173.236:8091/api/client-logs` | 실패 | OPS hang + scheme 불일치 (외부는 https) |
| 도메인 `appletreeda.synology.me` | DNS 정상 | — |
| 외부 포트 접속 테스트 | 8089 성공, 8091 hang | OPS hang |

- 사용자가 `http://211.253.173.236:8091/...` 로 입력한 방식이 **실제로 동작하는 방식** (OPS는 HTTP only).
- 클라이언트 외부 프로파일은 http 사용. OPS에 HTTPS를 적용하면 보안 강화 가능(서버 측 선택).
- scheme 불일치는 부차적; 근본 원인은 OPS hang.

---

## 5. 서버 측 필요 조치 (MacPro AI 에이전트에게)

### 5.1 즉시 조치 (P0)

1. **OPS 컨테이너 상태 확인**
   ```bash
   docker ps -a | grep kibal-dev-ops   # 또는 ops
   docker logs --tail 100 kibal-dev-ops
   ```
2. **OPS 컨테이너 재시작**
   ```bash
   docker restart kibal-dev-ops
   # 또는 docker compose -f deploy/dev/compose.yaml restart ops
   ```
3. **재시작 후 검증**
   ```bash
   curl -s http://192.168.11.5:8091/api/client-logs -X POST \
     -H 'Content-Type: application/json' -H 'X-Client-Key: dev-kibal-clients-2026' \
     -d '{"session":"test","extension":"0","lines":[]}'
   # 기대: 2xx JSON 응답
   curl -s http://192.168.11.5:8091/api/client/config -H 'X-Client-Key: dev-kibal-clients-2026'
   # 기대: 200 + data (sipDomain, wsServer, opsBaseUrl 등)
   ```

### 5.2 OPS hang 원인 조사 (P1)

- OPS 프로세스가 TCP accept 후 HTTP 파싱 단계에서 블로킹되는지 확인 (스레드 덤프, 데드락).
- DB/파일시스템 락, 메모리 부족, 디스크 full 여부 확인.
- OPS 로그에서 최근 에러/panic 확인.
- 재시작 후 동일 증상 재발 시: 코드 레벨 디버깅 필요 (OPS 서버 리포지토리).

### 5.3 포트포워딩 확인 (이미 동작 중, 참고)

- IPTime1: 8089/TCP, 10000-10200/UDP → 192.168.11.5 (확인됨, 8089 정상)
- 8091/TCP → 192.168.11.5 (TCP open 확인됨, OPS 재시작으로 HTTP 복구 예상)
- 5060/UDP 미개방 (정상, SIP는 WSS 8089 사용)

### 5.4 외부망 로그 전송 정책

- 외부망에서는 OPS 8091이 개방되어 있으므로 (TCP 확인), OPS 재시작 후 외부 로그 전송 가능.
- 클라이언트 외부 프로파일은 `http://appletreeda.synology.me:8091/api/client-logs` 사용 (OPS HTTP only).
- (선택) OPS에 TLS 적용 시 https로 전환 가능.
- 사용자가 `http://` 로 입력하면 scheme 불일치로 실패. 설정 화면 "서버에서 자동 설정" 버튼으로 https URL 자동 적용 권장.

---

## 6. 클라이언트 측 후속 작업 (서버 복구 후)

1. OPS 재시작 후 클라이언트에서 설정 → 연결 프로필(DEV/PRD/외부망) 전환 테스트.
2. 로그 전송 설정 → "연결 테스트" 버튼으로 각 프로파일 URL 검증.
3. 외부망 단말에서 `https://appletreeda.synology.me:8091/api/client-logs` 연결 테스트.
4. `ops_client_logs.sh list` 로 수신 현황 확인.

---

## 7. 부록: 진단 명령 모음

```bash
# DNS
dig +short appletreeda.synology.me

# 포트 도달성
nc -zv -G 5 appletreeda.synology.me 8089
nc -zv -G 5 appletreeda.synology.me 8091
nc -zv -G 5 211.253.173.236 8091

# HTTP 응답 확인
curl -v --connect-timeout 5 --max-time 8 http://211.253.173.236:8091/api/client-logs
curl -v --connect-timeout 5 --max-time 8 https://appletreeda.synology.me:8091/api/client-logs

# 내부 OPS
curl -s --max-time 5 http://192.168.11.5:8091/api/client/config -H 'X-Client-Key: dev-kibal-clients-2026'

# ops_client_logs
OPS_URL=http://192.168.11.5:8091 ./scripts/ops_client_logs.sh list
```

---

**작성**: SmartCC_Kibal-Client macOS 클라이언트 측 AI 에이전트
**전달 대상**: MacPro (192.168.11.5) 서버 AI 코딩 에이전트
**클라이언트 브랜치/커밋**: `feature/external-network-access` @ `328ca2ce`
