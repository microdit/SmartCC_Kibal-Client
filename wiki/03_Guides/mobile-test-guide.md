# Kibal Mobile 테스트 가이드

| 항목 | 내용 |
|------|------|
| **문서 ID** | GUIDE-MOBILE-TEST-20261105-001 |
| **문서명** | Kibal Mobile 테스트 가이드 |
| **작성일** | 2026-11-05 |
| **버전** | v1.0 |
| **대상** | SmartCC Kibal QA 테스터, 개발자 |
| **관련 문서** | [[wiki/03_Guides/PoC_테스트_절차_안내서_20261103]], [[wiki/03_Guides/mobile-usage-guide]], [[wiki/06_Reports/CT03_CT04_검수결과_보고서_20261105]] |

---

## 🧪 1. 개요

본 문서는 **Kibal Mobile**의 테스트 방법을 상세히 설명합니다. CT03 (SIP 등록)과 CT04 (1:1 영상통화) 테스트를 위해 필요합니다.

> **대상**: QA 테스터, 개발자, 시스템 관리자
> **목적**: Kibal Mobile의 기능 검증, 버그 식별, 품질 확인

---

## 🎯 2. 테스트 환경

### 2.1 테스트 장비

| 장비 | 사양 | 비고 |
|------|------|------|
| **iOS 디바이스** | iPhone/iPad (iOS 15+) | iOS 시뮬레이터 사용 가능 |
| **Android 디바이스** | Android 10+ | Android 에뮬레이터 사용 가능 |
| **Web 브라우저** | Chrome, Firefox, Safari | Web 클라이언트 테스트용 |
| **서버** | NAS2 (`kibal-prd-asterisk`) | Asterisk 22 LTS |

### 2.2 테스트 계정

| 내선 | 프로토콜 | 비밀번호 | 용도 |
|------|----------|----------|------|
| 1001 | UDP | (PRD 비밀번호) | Mobile UDP 테스트 |
| 1002 | UDP | (PRD 비밀번호) | Mobile UDP 테스트 |
| 1003 | UDP | (PRD 비밀번호) | Mobile UDP 테스트 |
| 1004 | UDP | (PRD 비밀번호) | Mobile UDP 테스트 |
| 1101 | WebSocket | (PRD 비밀번호) | Mobile/Web WebSocket 테스트 |
| 1102 | WebSocket | (PRD 비밀번호) | Mobile/Web WebSocket 테스트 |
| 1103 | WebSocket | (PRD 비밀번호) | Web 테스트 |
| 1104 | WebSocket | (PRD 비밀번호) | Web 테스트 |

### 2.3 서버 정보

| 항목 | 값 | 비고 |
|------|-----|------|
| **서버 주소** | 192.168.11.2 | NAS2 IP |
| **UDP 포트** | 5060 | SIP UDP 포트 |
| **WebSocket 포트** | 8088 | SIP WebSocket 포트 |
| **WebSocket URL** | ws://192.168.11.2:8088/ws | WebSocket endpoint |
| **RTP 포트 범위** | 10000-20000 | 미디어 포트 |
| **회의실** | 6000 | ConfBridge SFU |

---

## 📋 3. 테스트 준비

### 3.1 Flutter 개발 환경 설정

**Flutter SDK 설치:**
```bash
# macOS
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_-stable.zip -o ~/flutter.zip
unzip ~/flutter.zip -d ~/
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**의존성 설치:**
```bash
flutter doctor
flutter doctor --android-licenses  # Android 라이선스 동의
sudo gem install cocoapods          # iOS 의존성
```

**Xcode 설치:**
- App Store에서 Xcode 설치
- Xcode 실행 후 Command Line Tools 설치

**Java JDK 설치:**
- Oracle JDK 17+ 또는 OpenJDK 17+ 설치

### 3.2 Mobile 앱 빌드

**iOS 빌드:**
```bash
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/mobile
flutter pub get
flutter build ios --no-codesign
```

**Android 빌드:**
```bash
flutter build apk
```

**실행:**
```bash
# iOS 시뮬레이터
flutter run -d iPhone

# Android 에뮬레이터
flutter run -d emulator-5554

# 실기기 (USB 연결)
flutter run -d <device-id>
```

### 3.3 서버 확인

**Asterisk PRD 상태 확인:**
```bash
# PJSIP transport 확인
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show transports"'

# PJSIP endpoint 확인
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show endpoints"'

# HTTP/WebSocket 서버 상태
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "http show status"'

# ConfBridge 상태
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "confbridge list"'
```

---

## 🧪 4. CT03 테스트 (SIP 등록)

### 4.1 테스트 목표

Mobile 앱이 Asterisk PRD 서버에 SIP 등록 성공하는지 확인합니다.

### 4.2 테스트 절차

#### 테스트 1: UDP SIP 등록 (1001)

1. **앱 실행**
   - Mobile 앱을 실행합니다.

2. **SIP 계정 설정**
   - 내선 번호: `1001`
   - 비밀번호: (PRD 비밀번호)
   - 서버 도메인: `192.168.11.2`
   - 포트: `5060`
   - 전송 프로토콜: `UDP`

3. **등록 실행**
   - "SIP 등록" 버튼을 누릅니다.

4. **상태 확인**
   - 앱 상태가 "등록됨"으로 표시되는지 확인합니다.

5. **서버 확인**
   ```bash
   ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show contacts"'
   ```
   - **기대 출력**: `1001/sip:1001@...;transport=UDP ... Avail`

6. **등록 해제**
   - "등록 해제" 버튼을 누릅니다.
   - 상태가 "미등록"으로 표시되는지 확인합니다.
   - 서버에서 contact가 제거되었는지 확인합니다.

#### 테스트 2: WebSocket SIP 등록 (1101)

1. **앱 실행**
   - Mobile 앱을 실행합니다.

2. **SIP 계정 설정**
   - 내선 번호: `1101`
   - 비밀번호: (PRD 비밀번호)
   - 서버 도메인: `192.168.11.2`
   - 포트: `8088`
   - 전송 프로토콜: `WebSocket`
   - WebSocket 서버: `ws://192.168.11.2:8088/ws`

3. **등록 실행**
   - "SIP 등록" 버튼을 누릅니다.

4. **상태 확인**
   - 앱 상태가 "등록됨"으로 표시되는지 확인합니다.

5. **서버 확인**
   ```bash
   ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show contacts"'
   ```
   - **기대 출력**: `1101/sip:1101@...;transport=WS ... Avail`

6. **등록 해제**
   - "등록 해제" 버튼을 누릅니다.

### 4.3 합격 기준

| 기준 | 확인 방법 | 통과 여부 |
|------|-----------|-----------|
| REGISTER 200 OK 응답 | 앱 로그 또는 Asterisk 로그 | ✅/❌ |
| Asterisk contact 확인 | `pjsip show contacts` | ✅/❌ |
| 등록 해제 후 contact 제거 | `pjsip show contacts` | ✅/❌ |
| 앱 콘솔에 인증 오류 없음 | 앱 UI 또는 로그 | ✅/❌ |

### 4.4 증거 자료

- [ ] 앱 스크린샷 (등록 성공)
- [ ] 앱 스크린샷 (등록 해제)
- [ ] `pjsip show contacts` 출력 (등록 후)
- [ ] `pjsip show contacts` 출력 (등록 해제 후)
- [ ] Asterisk 로그 (REGISTER 메시지)

---

## 📞 5. CT04 테스트 (1:1 영상통화)

### 5.1 테스트 목표

Mobile 단말 2대에서 1:1 영상통화를 성공적으로 수행하는지 확인합니다.

### 5.2 테스트 절차

#### 테스트 1: Mobile ↔ Mobile 통화 (UDP)

1. **단말 A 준비**
   - 내선: `1001` (UDP)
   - SIP 등록 성공 확인

2. **단말 B 준비**
   - 내선: `1002` (UDP)
   - SIP 등록 성공 확인

3. **통화 시작 (A → B)**
   - 단말 A에서 다이얼러 화면 열기
   - 내선 번호 `1002` 입력
   - "호출" 버튼 누르기

4. **통화 수신 (B)**
   - 단말 B에서 수신 알림 확인
   - "수신" 버튼 누르기

5. **통화 확인**
   - 양쪽 단말에서 세션 상태가 "Established"로 표시되는지 확인
   - 양방향 오디오 확인 (소리 들림)
   - 양방향 영상 확인 (영상 보임)

6. **서버 확인**
   ```bash
   # 채널 확인
   ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "core show channels"'
   
   # RTP 통계 확인
   ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show channelstats"'
   ```

7. **통화 종료**
   - 단말 A에서 "통화 종료" 버튼 누르기
   - 양쪽 단말에서 세션이 종료되는지 확인
   - 서버에서 채널이 제거되는지 확인

#### 테스트 2: Mobile ↔ Mobile 통화 (WebSocket)

1. **단말 A 준비**
   - 내선: `1101` (WebSocket)
   - SIP 등록 성공 확인

2. **단말 B 준비**
   - 내선: `1102` (WebSocket)
   - SIP 등록 성공 확인

3. **통화 시작~종료**
   - 위와 동일한 절차 수행

#### 테스트 3: Mobile ↔ Web 통화 (보조 확인)

1. **Mobile 준비**
   - 내선: `1001` (UDP) 또는 `1101` (WebSocket)
   - SIP 등록 성공 확인

2. **Web 준비**
   - Web 클라이언트 (`http://127.0.0.1:5173`) 접속
   - 내선: `1102` (WebSocket)
   - SIP 등록 성공 확인

3. **통화 시작~종료**
   - Mobile에서 Web 내선 번호로 호출
   - Web에서 수신
   - 양방향 영상/오디오 확인

### 5.3 합격 기준

| 기준 | 확인 방법 | 통과 여부 |
|------|-----------|-----------|
| 양쪽 세션 Established | 앱 UI 또는 Asterisk 로그 | ✅/❌ |
| 양방향 오디오 확인 | 사용자 확인 | ✅/❌ |
| 양방향 영상 확인 | 사용자 확인 | ✅/❌ |
| H.264 코덱 협상 | SDP 메시지 확인 | ✅/❌ |
| RTP 송수신 확인 | `pjsip show channelstats` | ✅/❌ |
| 종료 후 채널 해제 | `core show channels` | ✅/❌ |

### 5.4 증거 자료

- [ ] 단말 A 스크린샷 (통화 중)
- [ ] 단말 B 스크린샷 (통화 중)
- [ ] `core show channels` 출력 (통화 중)
- [ ] `pjsip show channelstats` 출력
- [ ] Asterisk 로그 (INVITE/200 OK/BYE 메시지)
- [ ] `sngrep` 캡처 (SIP 메시지 흐름)

---

## 📊 6. 추가 테스트

### 6.1 camera 전환 테스트

1. 통화 중 상태에서 카메라 전환 버튼 누르기
2. 전면 ↔ 후면 카메라 전환 확인

**합격 기준:**
- [ ] 카메라 전환 성공
- [ ] 영상이 정상적으로 표시

### 6.2 음소거 테스트

1. 통화 중 "음소거" 버튼 누르기
2. 마이크가 mute 되는지 확인
3. 다시 누르면 un-mute 되는지 확인

**합격 기준:**
- [ ] 마이크 mute/onmute 전환 성공
- [ ] 상대방에서 소리 변화 확인

### 6.3 스피커 테스트

1. 통화 중 "스피커" 버튼 누르기
2. 스피커가 mute 되는지 확인
3. 다시 누르면 un-mute 되는지 확인

**합격 기준:**
- [ ] 스피커 mute/unmute 전환 성공
- [ ] 소리가 정상적으로 들림/들리지 않음

### 6.4 네트워크 변화 테스트

1. Wi-Fi에서 모바일 데이터로 전환
2. SIP 등록 유지 확인
3. 통화 중이라면 통화 유지 확인

**합격 기준:**
- [ ] 네트워크 전환 시 SIP 등록 유지
- [ ] 통화 유지 (Reconnection Logic 구현 시)

---

## 🔍 7. 장애 진단

### 7.1 SIP 등록 실패

| 증상 | 원인 | 진단 방법 | 해결 방법 |
|------|------|-----------|------------|
| "SIP 서버에 연결할 수 없습니다" | 네트워크 문제 | `ping 192.168.11.2` | 네트워크 연결 확인 |
| | 서버 포트 차단 | `nc -vz 192.168.11.2 5060` | 방화벽 확인 |
| | 서버 미실행 | `docker ps` | Asterisk 컨테이너 확인 |
| "인증 실패" | 잘못된 비밀번호 | 비밀번호 확인 | 비밀번호 재입력 |
| | 잘못된 내선 번호 | `pjsip show endpoints` | endpoint 확인 |
| "등록 거부" | endpoint 미구성 | `pjsip show endpoint 1001` | endpoint 구성 확인 |

### 7.2 통화 실패

| 증상 | 원인 | 진단 방법 | 해결 방법 |
|------|------|-----------|------------|
| "통화를 시작할 수 없습니다" | SIP 등록되지 않음 | 앱 상태 확인 | SIP 등록 먼저 수행 |
| | 상대방 미등록 | `pjsip show contacts` | 상대방 등록 확인 |
| "세션 생성 실패" | RTP 포트 문제 | `netstat -an grep 10000-20000` | RTP 포트 확인 |
| | 코덱 미지원 | SDP 메시지 확인 | H.264/VP8 코덱 확인 |

### 7.3 영상/오디오 문제

| 증상 | 원인 | 진단 방법 | 해결 방법 |
|------|------|-----------|------------|
| "영상이 표시되지 않음" | 카메라 권한 거부 | 설정 > Kibal Mobile > 카메라 | 권한 허용 |
| | 카메라 사용 중 | 다른 앱 확인 | 다른 앱 종료 |
| "소리가 들리지 않음" | 마이크 권한 거부 | 설정 > Kibal Mobile > 마이크 | 권한 허용 |
| | 스피커 mute | "스피커" 버튼 확인 | 스피커 un-mute |
| | 볼륨 문제 | 디바이스 볼륨 확인 | 볼륨 조정 |

### 7.4 Asterisk 서버 진단

**PJSIP transport 확인:**
```bash
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show transports"'
```
- 기대: `transport-udp 0.0.0.0:5060`, `transport-ws 0.0.0.0:8088`

**PJSIP endpoint 확인:**
```bash
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "pjsip show endpoint 1001"'
```
- 기대: endpoint가 존재하고 `Status: Reachable`

**HTTP/WebSocket 확인:**
```bash
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "http show status"'
```
- 기대: `Server Enabled and Bound to 0.0.0.0:8088`, `/ws` 활성

**RTP/ICE 확인:**
```bash
ssh nas2 'export PATH=/usr/local/bin:$PATH; docker exec kibal-prd-asterisk /usr/sbin/asterisk -C /run/asterisk/asterisk.conf -rx "rtp show settings"'
```
- 기대: `icesupport: yes`

---

## 📝 8. 테스트 체크리스트

### 8.1 CT03 테스트 체크리스트

- [ ] Mobile 앱 설치 및 실행
- [ ] SIP 계정 정보 입력 (UDP 1001)
- [ ] SIP 등록 성공
- [ ] 상태 "등록됨" 확인
- [ ] Asterisk contact 확인 (`pjsip show contacts`)
- [ ] 등록 해제 성공
- [ ] contact 제거 확인
- [ ] SIP 계정 정보 입력 (WebSocket 1101)
- [ ] SIP 등록 성공
- [ ] Asterisk contact 확인
- [ ] 스크린샷 캡처
- [ ] 로그 저장

### 8.2 CT04 테스트 체크리스트

- [ ] Mobile 앱 설치 및 실행 (단말 A)
- [ ] SIP 등록 (1001)
- [ ] Mobile 앱 설치 및 실행 (단말 B)
- [ ] SIP 등록 (1002)
- [ ] A에서 B로 호출
- [ ] B에서 수신
- [ ] 양쪽 Established 확인
- [ ] 양방향 오디오 확인
- [ ] 양방향 영상 확인
- [ ] Asterisk 채널 확인 (`core show channels`)
- [ ] RTP 통계 확인 (`pjsip show channelstats`)
- [ ] A에서 통화 종료
- [ ] 양쪽 세션 종료 확인
- [ ] 스크린샷 캡처
- [ ] 로그 저장

---

## 📊 9. 테스트 결과 기록

### 9.1 CT03 테스트 결과

| 테스트 | 결과 | 비고 |
|--------|------|------|
| UDP SIP 등록 (1001) | ⬜ | |
| WebSocket SIP 등록 (1101) | ⬜ | |
| 등록 해제 | ⬜ | |

### 9.2 CT04 테스트 결과

| 테스트 | 결과 | 비고 |
|--------|------|------|
| Mobile ↔ Mobile 통화 (UDP) | ⬜ | |
| Mobile ↔ Mobile 통화 (WebSocket) | ⬜ | |
| Mobile ↔ Web 통화 | ⬜ | |

### 9.3 증거 자료

| 자료 | 위치 | 비고 |
|------|------|------|
| 스크린샷 | `~/kibal-poc-YYYYMMDD-HHMMSS/` | CT03/CT04 스크린샷 |
| 로그 | `~/kibal-poc-YYYYMMDD-HHMMSS/` | Asterisk 로그, 앱 로그 |
| `sngrep` 캡처 | `~/kibal-poc-YYYYMMDD-HHMMSS/` | SIP 메시지 캡처 |

---

## 📚 10. 관련 문서

### 10.1 테스트 관련 문서

| 문서 | 위치 | 설명 |
|------|------|------|
| PoC 테스트 절차 | [[wiki/03_Guides/PoC_테스트_절차_안내서_20261103]] | CT01~CT06 테스트 절차 |
| CT03/CT04 검수 결과 | [[wiki/06_Reports/CT03_CT04_검수결과_보고서_20261105]] | 검수 결과 |
| CT03/CT04 자체 검수 | [[wiki/06_Reports/CT03_CT04_자체_검수_보고서_20261105]] | 자체 검수 결과 |

### 10.2 사용자 가이드

| 문서 | 위치 | 설명 |
|------|------|------|
| Mobile 사용자 가이드 | [[wiki/03_Guides/mobile-usage-guide]] | Mobile 앱 사용법 |
| Web 사용자 가이드 | [[wiki/03_Guides/usage-guide]] | Web 클라이언트 사용법 |

---

## 📅 11. 문서 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-11-05 | TVS (Mistral Vibe) | 최초 작성 |

---

*본 문서는 Kibal Mobile의 테스트를 위한 종합 가이드입니다.*
*테스트 결과는 Wiki에 문서화되어야 합니다.*
