# Kibal Client 개발 가이드 (Development Guide)

| 항목 | 내용 |
|------|------|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **상태** | 작업중 |
| **관련** | [[wiki/01_Projects/client-project-plan]], [[wiki/02_Design/web-client]], [[wiki/02_Design/mobile-client]] |

> **별도 리포지토리**: `SmartCC_Kibal-Client`

---

## 1. 프로젝트 초기화 (Stage C1)

### 1.1 Git 저장소 생성

```bash
# 1. GitHub에 새 저장소 생성 (github.com/mircodit/SmartCC_Kibal-Client)
# 2. 로컬 클론
git clone git@github.com:microdit/SmartCC_Kibal-Client.git
cd SmartCC_Kibal-Client

# 3. Remote 3-Way 설정 (github/dev/prd)
git remote add github git@github.com:microdit/SmartCC_Kibal-Client.git
git remote add dev ssh://atom@nas2:4949/volume1/gitRepo/SmartCC_Kibal-Client.git
git remote add prd  ssh://atom@nas2:4949/volume1/gitRepo/SmartCC_Kibal-Client_prd.git

# 4. 9-Layer Wiki 구조 생성
mkdir -p wiki/{01_Projects,02_Design,03_Guides,04_Prompts,05_Decisions,06_Reports,07_Logs,08_Experiments,09_Knowledge}

# 5. Python 3.11 venv 생성
python3.11 -m venv venv_client
source venv_client/bin/activate
pip install chromadb==1.5.9
```

### 1.2 디렉토리 구조

```
SmartCC_Kibal-Client/
├── CLAUDE.md                     ← Agent Memory v3.0
├── docs/
│   ├── 작업지시서.md               ← Knowledge OS Kernel
│   ├── AGENTS.md                 ← Agent Memory v3.0
│   └── _작업이력/
│       └── log/                  ← git-sync 자동 로그
├── wiki/                         ← 9-Layer Wiki
├── scripts/
│   ├── git-sync.sh               ← 3-Way push
│   ├── generate-commit-msg.py    ← 커밋 메시지 자동 생성
│   └── index_wiki.py             ← ChromaDB 인덱싱
├── agent_wiki_vector.py          ← Vector Store 엔진
├── venv_client/                  ← Python 3.11 venv
├── vector_db/                    ← ChromaDB Persistent DB
├── web/                          ← React Web Client
├── mobile/                       ← Flutter Mobile Client
├── docker-compose.yml            ← 통합 배포
└── requirements.txt             ← chromadb==1.5.9
```

---

## 2. Web Client 개발 (Stage C2)

### 2.1 환경 설정

```bash
cd web/
npm install

# 개발 서버 실행
npm run dev

# 빌드
npm run build
```

### 2.2 핵심 스크릿

| 파일 | 설명 |
|------|------|
| `src/sip/SipClient.ts` | SIP.js UserAgent 래퍼 (등록/발신/수신) |
| `src/sip/MediaManager.ts` | WebRTC MediaStream 관리 (getUserMedia, PeerConnection) |
| `src/sip/ConferenceManager.ts` | ConfBridge SFU 회의 참여/퇴장 |
| `src/store/index.ts` | Zustand 상태 관리 (sip, media, conference) |

### 2.3 SIP 등록 테스트 (CT01)

1. Asterisk 서버의 WSS 엔드포인트 확인 (`wss://192.168.11.2:8090/ws`)
2. 브라우저에서 `sip.js` 등록 테스트
3. Asterisk CLI에서 `pjsip show registrations` 확인

```bash
# Asterisk CLI
asterisk -rx "pjsip show registrations"
# 기대 출력: 1001 등록됨 (Registered)
```

### 2.4 1:1 영상통화 테스트 (CT02)

1. 두 브라우저에서 각각 1001, 1002로 등록
2. 다이얼러에서 1002 입력 → INVITE 전송
3. SDP offer/answer 교환 → RTP 스트림 확인
4. 영상 확인 → BYE로 종료

---

## 3. Mobile Client 개발 (Stage C3)

### 3.1 Flutter 환경 설정

```bash
cd mobile/
flutter pub get

# iOS 시뮬레이터 실행
flutter emulators --create --name=kibal-ios
flutter emulators --launch kibal-ios
flutter run

# Android 에뮬레이터 실행
flutter emulators --create --name=kibal-android
flutter emulators --launch kibal-android
flutter run
```

### 3.2 네이티브 권한

iOS와 Android 모두 카메라/마이크 권한이 필요합니다. 자세한 설정은 [[wiki/02_Design/mobile-client]] 참조.

### 3.3 모바일 테스트 (CT03, CT04)

| 테스트 ID | 설명 | 방법 |
|-----------|------|------|
| CT03 | SIP.js 등록 (Web) | 브라우저 접속 → REGISTER 전송 |
| CT04 | 1:1 영상통화 (Mobile) | Flutter 앱 → 내선 호출 → 영상 확인 |

---

## 4. Docker 배포 (Stage C4)

### 4.1 Web Client 컨테이너화

```dockerfile
# Dockerfile.web
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --frozen-lockfile
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 4.2 docker-compose.yml

```yaml
version: "3.9"
services:
  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: kibal-web
    ports:
      - "80:80"
    networks:
      - kibal-net

networks:
  kibal-net:
    driver: bridge
```

---

## 5. 통합 테스트 (Stage C5)

Server (`SmartCC_Kibal`) + Client (`SmartCC_Kibal-Client`) 3자 회의 검증:

| 테스트 ID | 설명 | 검증 방법 |
|-----------|------|-----------|
| CT05 | 3자 SFU 회의 (Web) | 3개 브라우저 → 회의실 6000 참여 |
| CT06 | NAT 통과 (STUN) | 공인망 클라이언트 → 서버 연결 |

---

## 6. Git 워크플로

### 6.1 기능 개발

```bash
git checkout -b feature/기능이름
# ... 작업 ...
./scripts/git-sync.sh --auto --no-deploy
```

### 6.2 PRD 배포

```bash
./scripts/git-sync.sh --auto --deploy
```

### 6.3 커밋 메시지 규칙

```
feat: 새 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 리팩토링
test: 테스트 코드
chore: 빌드/설정
design: 설계 변경
```

---

## 7. Wiki 인덱싱

```bash
# Python 3.11 venv 활성화
source venv_client/bin/activate

# 전체 Wiki 재인덱싱
./venv_client/bin/python scripts/index_wiki.py --reindex

# 의미 검색
./venv_client/bin/python scripts/index_wiki.py --search "WebRTC"

# 통계
./venv_client/bin/python scripts/index_wiki.py --stats
```

---

## 8. 관련 문서

- [[wiki/01_Projects/client-project-plan]] — 클라이언트 프로젝트 계획
- [[wiki/02_Design/sip-client-design]] — SIP 클라이언트 설계
- [[wiki/02_Design/web-client]] — Web Client 상세 설계
- [[wiki/02_Design/mobile-client]] — Mobile Client 설계
- [[wiki/05/Decisions/ADR-002]] — WebRTC + SIP.js 결정