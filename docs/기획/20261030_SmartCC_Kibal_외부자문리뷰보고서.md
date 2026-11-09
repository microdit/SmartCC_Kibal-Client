# SmartCC_Kibal 프로젝트 외부 자문 리뷰 보고서

| 항목 | 내용 |
|------|------|
| **보고서 ID** | EXT-REV-20261030-001 |
| **작성일** | 2026-10-30 |
| **작성자** | IT 전문 분석·설계 외부 자문 (OpenCode) |
| **대상** | `SmartCC_Kibal` 서버 저장소, `SmartCC_Kibal-Client` 문서, 로컬 Docker 환경 |
| **기준 커밋** | 로컬 `e3316c4` / `origin/main` `7d0f7de` |
| **검토 방식** | 저장소·문서 정적 분석, Git 이력 대조, Docker/런타임 상태 조회, 경량 자체 검증 |
| **문서 상태** | 최종 초안 (의사결정 참고용) |
| **중요 전제** | 실제 Asterisk 빌드, SIP 단말 연결, 부하·보안 시험은 이 환경에서 수행하지 못했습니다. 본 보고서의 “검증”은 저장소·환경 수준의 자체 검증입니다. |

---

## 1. 경영 요약 (Executive Summary)

### 1.1 종합 평가

**현재 단계: “설계·지식관리 초기 문서 단계”이며, 실행 가능한 제품 MVP는 아직 저장소에 존재하지 않습니다.**

| 평가 영역 | 성숙도(자문 판단) | 요약 |
|-----------|------------------|------|
| 프로젝트 문서·지식관리 | 60~70% | Knowledge OS 구조, 아키텍처·라이선스·SIP 설계 문서는 방향성이 있음 |
| 실행 가능한 구현물 | 10~15% | Asterisk Compose/Dockerfile/설정/검증 스크립트가 저장소에 없음 |
| 기능 검증 | 5~10% | T01~T08 전 항목 미실행, SIP/RTP 패킷 검증 이력 없음 |
| 운영 준비 | 10~15% | 모니터링·백업·보안·CI/CD·릴리스 체계 미구축 |
| Docker 인프라 | 15~20% | Docker는 동작하나 Kibal 관련 이미지·컨테이너가 전무하며 개발 호스트가 macOS Docker Desktop임 |
| **종합** | **설계 초안 / MVP 착수 전** | **문서는 “무엇을 만들지” 설명하지만, “실제로 만들었다”는 증거가 부족** |

### 1.2 핵심 결론

1. **가장 큰 문제는 기능 부족이 아니라 “실행 증거의 부재”입니다.**  
   `compose.yaml`, `Dockerfile`, `config/*`, `scripts/start.sh`, `verify.sh` 등이 저장소에 없습니다. 2026-10-29 리뷰 보고서는 “프로젝트 구성 파일 패키징 완료”로 평가했지만, 현재 저장소와 로컬 Downloads 경로에서 해당 패키지를 확인할 수 없었습니다.

2. **Git source of truth가 어긋나 있습니다.**  
   로컬 HEAD는 `origin/main`보다 **3커밋 뒤처져** 있고, 로컬에는 미커밋 변경(`scripts/git-pull.sh`)과 미추적 문서(`docs/준비문서/`)가 있습니다. 또한 문서는 `github/dev/prd` 3-way remote를 주장하지만, 현재 클론에는 `origin` 하나만 설정되어 있습니다.

3. **Docker는 실행 중이지만 Kibal용 이미지·컨테이너는 없습니다.**  
   현재 Docker Desktop은 2022~2023년 수준의 엔진(20.10.22)이며, macOS Docker Desktop의 host network는 Linux와 동일하게 동작하지 않습니다. SIP/RTP PoC는 **Ubuntu 24.04 Linux 호스트 또는 NAS/Linux VM**에서 수행해야 합니다.

4. **설계 방향은 타당하나, 일부 설정 예시는 실제 Asterisk 설정과 불일치합니다.**  
   `[general] mixer = audio`, `sfu = video` 같은 예시는 ConfBridge 실제 설정 문법과 다를 가능성이 높습니다. ConfBridge SFU는 bridge 프로필의 `video_mode=sfu` 등으로 검증해야 합니다.

5. **성능 목표(특히 100명)는 현재 구조로 달성 불가능할 가능성이 큽니다.**  
   Asterisk ConfBridge SFU는 소규모에는 적합하지만, 100명급 다자간 영상은 전용 SFU/계층형 미디어 서버 없이는 대역폭·패킷 처리·CPU 한계에 부딪힙니다. 30명 이상은 반드시 실측 후 의사결정해야 합니다.

### 1.3 즉시 조치 Top 5

| 순위 | 조치 | 이유 | 완료 기준 |
|------|------|------|-----------|
| 1 | 작업 트리 정리 및 `origin/main` 동기화 | 로컬이 3커밋 뒤처져 문서·구조가 불일치 | `git status` clean, `origin/main`과 동일 HEAD |
| 2 | MVP 실행 산출물 저장소에 커밋 | 현재는 문서만 있고 실행 불가 | `docker compose config` 성공, 이미지 빌드 성공 |
| 3 | Linux 호스트에서 Asterisk 기동 및 T01 검증 | macOS host network는 SIP/RTP PoC에 부적합 | 4개 내선 REGISTER 성공 로그 |
| 4 | 1:1 영상통화(T03)와 3자 SFU(T05) 실측 | 핵심 가설 검증 | SIP/SDP/RTP 캡처 및 영상 확인 |
| 5 | 보안·라이선스·CI 최소 기준 수립 | 외부 노출 및 납품 리스크 | 비밀번호 분리, TLS/SRTP 계획, SBOM/고지, CI 통과 |

---

## 2. 검토 범위와 방법

### 2.1 검토 범위

- `SmartCC_Kibal` 로컬 저장소 전체 (22개 추적 파일)
- `origin/main`의 최신 문서 (로컬보다 3커밋 앞선 상태)
- `docs/준비문서/`의 기획·라이선스·리뷰 문서
- `SmartCC_Kibal-Client` 저장소 (문서 중심, 코드 부재 확인)
- 로컬 Docker Desktop, 이미지·컨테이너·포트·Python 런타임
- Git remote·동기화 상태, Wiki/Vector DB 자체 검증

### 2.2 수행 방법

1. 저장소 파일·문서·스크립트 정적 분석
2. `origin/main`과 로컬 HEAD 비교 (`git rev-list`, `git diff`, `git show`)
3. Docker 상태 조회 (`docker version`, `docker info`, `docker ps -a`, `docker images`)
4. Python/스크립트 경량 검증 (`py_compile`, `bash -n`, ChromaDB 인덱싱·검색)
5. 누락 파일·깨진 참조·문서 주장과 실제 상태 대조

### 2.3 검토하지 못한 항목

- Asterisk 실제 빌드 및 기동
- SIP 영상전화기/소프트폰 연결
- SIP REGISTER, INVITE, RTP/RTCP, H.264 협상
- 다자간 ConfBridge SFU 영상 표시
- 부하·장시간 안정성·NAT/TURN·보안 스캔
- NAS PRD 배포

> 본 보고서는 “현재 저장소와 로컬 환경에서 확인 가능한 사실”과 “설계 문서의 주장”을 구분하여 작성했습니다. 확인되지 않은 항목은 `미검증`으로 표기합니다.

---

## 3. 현재 상태 스냅샷

### 3.1 Git·저장소

| 항목 | 확인 결과 | 판정 |
|------|-----------|------|
| 로컬 HEAD | `e3316c4` (feat: CLAUDE.md, README.md) | 기준 |
| `origin/main` | `7d0f7de` (AGENTS.md, 작업지시서, 06~09 Wiki 등 추가) | 로컬보다 3커밋 앞 |
| 로컬–원격 관계 | `origin/main...HEAD` = 3 / 0 (뒤처짐) | **불일치** |
| 작업 트리 | `M scripts/git-pull.sh`, `?? docs/준비문서/` | **미정리** |
| Remote | `origin`만 존재 (HTTPS GitHub) | 문서의 3-way 주장과 불일치 |
| 추적 파일 | 22개 | 매우 적음 |
| 브랜치 | 로컬 `main`만, 원격 `origin/main` | 단일 브랜치 |
| Wiki 디렉토리 | 로컬 01~05만 존재, 06~09 없음 | origin에는 06~09 존재 |
| `docs/AGENTS.md`, `docs/작업지시서.md` | 로컬에 없음, origin에만 존재 | **미동기화** |
| 벡터 DB | `vector_db/` 없음 (gitignore) | 재생성 필요 |
| `venv_kibal/` | 로컬에 없음 | 문서 주장과 불일치 |

**판정:** 저장소는 “문서 초기화 + Git 자동화 스크립트” 상태이며, 서버 제품 코드는 아직 없습니다. 로컬 작업본과 GitHub 최신본이 다르므로, 리뷰·개발 전에 반드시 동기화 기준을 확정해야 합니다.

### 3.2 Docker 환경

| 항목 | 확인 결과 | 비고 |
|------|-----------|------|
| Docker Desktop | 4.16.1 (95567) | 2023년 초 수준, 최신 보안 패치 확인 필요 |
| Docker Engine | 20.10.22 | 구버전 |
| Docker Compose | v2.15.1 | 구버전 |
| 아키텍처 | linux/amd64 (macOS x86_64) | ARM NAS와 이미지 호환성 확인 필요 |
| Docker VM 자원 | 8 CPU / 약 7.7 GiB RAM | 호스트는 16 CPU / 48 GiB |
| 실행 중 컨테이너 | 3개 (SmartCodexStudio 관련) | Kibal과 무관 |
| Kibal 컨테이너 | 없음 | **미구축** |
| Asterisk 이미지 | 없음 | **미구축** |
| SIP 5060 리스너 | 없음 | **미기동** |
| Compose 파일 | 없음 | `docker compose config` 실패 |
| Docker 디스크 | 이미지 3.585GB, 빌드 캐시 3.129GB, 볼륨 26.3GB | 프로젝트와 무관한 자원이 다수 |

**판정:** Docker 자체는 사용 가능하지만, Kibal 서비스를 실행할 이미지·컨테이너·Compose 정의가 전무합니다. 또한 macOS Docker Desktop은 SIP/RTP 검증용 운영 호스트로 부적합합니다.

### 3.3 Python·도구

| 항목 | 확인 결과 |
|------|-----------|
| 시스템 Python | 3.9.6 (`/usr/bin/python3`) |
| chromadb | 1.5.9 import 성공 |
| pytest | 8.4.2 설치됨 |
| Asterisk 바이너리 | 미설치 |
| `py_compile` | 5개 Python 파일 통과 |
| `bash -n` | 2개 셸 스크립트 통과 |
| 테스트 | `pytest -q` → **no tests ran (0개)** |

### 3.4 문서 주장 대 실제 확인

| 문서 주장 | 실제 확인 | 판정 |
|-----------|-----------|------|
| GitHub/dev/prd 3-way 동기화 완료 | 현재 클론은 `origin`만 존재 | **미검증/불일치** |
| Asterisk MVP 패키지 생성·ZIP 패키징 완료 | 저장소·Downloads에서 패키지 미발견 | **미확인** |
| `compose.yaml`, `Dockerfile`, `config/*`, `scripts/verify.sh` 존재 | 전부 없음 | **불일치** |
| `venv_kibal/` Python 3.11 + chromadb 1.5.9 | 디렉토리 없음 | **미확인** |
| ChromaDB 6문서 41청크 인덱싱 | 재현 성공 (41 chunks / 6 docs) | **확인** |
| 의미 검색 정상 (cosine > 0.5) | “SIP 영상통화” 0.625/0.603/0.537 | **확인** |
| Docker 검증 완료 | Kibal 이미지·컨테이너 없음 | **미완료** |
| T01~T08 검증 | 전 항목 미실행 | **미완료** |
| Wiki 9-Layer 구축 | 로컬은 01~05만, origin은 06~09 포함 | **부분 완료** |

---

## 4. 핵심 발견사항

### 4.1 P0 — 즉시 해결해야 하는 차단 요인

#### F-01. 실행 가능한 Asterisk MVP 산출물 부재

- **근거:** `compose.yaml`, `docker-compose.yml`, `Dockerfile`, `config/`, `scripts/start.sh`, `verify.sh`, `status.sh`, `capture.sh` 모두 없음.
- **영향:** 문서에 적힌 설치·검증 절차를 그대로 재현할 수 없고, “MVP 완료” 여부를 판단할 수 없습니다.
- **조치:** MVP 패키지를 저장소 루트 또는 `server/` 하위에 커밋하고, `docker compose config` 및 이미지 빌드까지 재현 가능하게 해야 합니다.

#### F-02. Git source of truth 불일치

- **근거:** 로컬 `e3316c4`, `origin/main` `7d0f7de`, 3커밋 뒤처짐. 미커밋 변경과 미추적 문서 존재. `dev`/`prd` remote 없음.
- **영향:** 문서·설계·구현이 서로 다른 버전을 참조하고, 배포 시 어떤 커밋이 기준인지 추적할 수 없습니다.
- **조치:** 작업 트리를 백업/정리한 뒤 `origin/main` 기준으로 동기화하고, remote 전략을 실제와 일치하게 문서화해야 합니다. 3-way가 필요하면 remote를 실제로 구성하고 검증 로그를 남겨야 합니다.

#### F-03. 검증된 실행 환경 부재 (macOS Docker Desktop)

- **근거:** Docker Desktop 4.16.1/Engine 20.10.22, macOS x86_64, Kibal 이미지·컨테이너 없음, 5060 리스너 없음.
- **영향:** host network 기반 SIP/RTP 설계는 macOS Docker Desktop에서 Linux와 동일하게 동작하지 않습니다. 이 환경에서의 “성공”은 PRD 성공을 보장하지 않습니다.
- **조치:** Ubuntu 24.04 LTS 물리/VM 또는 NAS(Linux)에서 검증합니다. macOS는 빌드·문법 검사·문서 작업용으로 한정합니다.

#### F-04. 기능 테스트 전무

- **근거:** T01~T08 전 항목 미실행, `pytest` 0개, `tests/` 디렉토리 없음, CI 없음.
- **영향:** SIP 등록, 영상 협상, SFU 다중 영상, CDR 등 핵심 가설이 모두 미검증입니다.
- **조치:** 최소한 T01(등록), T03(1:1 영상), T05(3자 SFU)부터 자동/수동 증거를 남기고, 이후 회귀 테스트로 전환합니다.

#### F-05. 보안·라이선스 운영 기준 부재

- **근거:** `.env.example` 없음, 비밀번호 평문 예시, TLS/SRTP/WSS 구성 미검증, fail2ban/ACL 없음, SBOM/THIRD_PARTY_NOTICES 없음.
- **영향:** 내부 LAN PoC를 넘어 외부망·고객사 납품으로 확장할 때 즉시 보안·GPL 의무 리스크가 발생합니다.
- **조치:** MVP 단계부터 secrets 분리, SIP ACL, TLS/SRTP 로드맵, GPL 소스 제공·고지·SBOM 체계를 문서와 저장소에 포함해야 합니다.

### 4.2 P1 — 제품화 전 반드시 해결해야 하는 주요 결함

#### F-06. 의존성·requirements 오류

- `sqlite3`는 Python 표준 라이브러리이며 pip 설치 대상이 아닙니다. 현재 `requirements.txt`에 그대로 적혀 있어 `pip install -r` 실패 가능성이 있습니다.
- `chroma`와 `chromadb`를 동시에 선언하는 것은 중복/충돌 위험이 있습니다.
- `bge-m3==0.1.0`은 일반적인 pip 패키지명과 모델명이 혼재된 형태로 보이며, 실제 사용 모델·런타임(`FlagEmbedding` 등)을 확정해야 합니다.
- `ariapy>=1.0`은 ARI 클라이언트로 쓰려는 패키지인지, 실제 PyPI 패키지·버전이 존재하는지 확인이 필요합니다.
- Flask는 선언되어 있지만 Flask 애플리케이션 코드가 없습니다.
- 버전 고정·lock 파일·Python 지원 범위(3.11/3.12 등)가 없습니다.

#### F-07. Docker 설계가 실제로 빌드·운영 가능한지 불명

- `image: asterisk:22-latest`는 태그 실재 여부·공식 이미지 여부·다이제스트 고정이 확인되지 않았습니다.
- bridge 네트워크에서 UDP `10000-20000`을 그대로 publish하면 NAT/conntrack 부하가 크고, SIP/RTP 양방향 통신이 불안정할 수 있습니다.
- `./asterisk/etc`, `./web`, `./vector_db` 등 마운트 대상 디렉토리가 저장소에 없습니다.
- `Dockerfile.api`가 없습니다.
- `.dockerignore`가 없고, `.gitignore`가 `.dockerignore`를 무시하도록 되어 있어 커밋 자체가 어렵습니다.

#### F-08. Asterisk 설정 예시의 문법·일관성 문제

- `wiki/02_Design/sip-client.md`의 ConfBridge 예시 `[general] mixer = audio`, `sfu = video`는 실제 ConfBridge 설정과 다를 가능성이 높습니다. ConfBridge는 bridge 프로필에서 `video_mode=sfu` 등을 사용하는 구조로 검증해야 합니다.
- RTP 포트 범위가 문서마다 다릅니다. 아키텍처는 `10000-20000`, SIP 클라이언트 설계는 `10000-10010`으로 기술되어 있습니다.
- CDR은 설계에서 CSV, 사용 가이드에서는 SQLite(`cdr.db`)로 조회하도록 되어 있어 저장 방식이 일관되지 않습니다.
- WebRTC를 언급하지만 `webrtc=yes`, ICE, DTLS-SRTP, WSS transport, TURN 연동의 실제 설정·검증 계획이 구체적이지 않습니다.
- H.264 프로파일(`42e01f`)과 SIP 단말·WebRTC 단말 간 협상 전략이 검증되지 않았습니다.

#### F-09. 관리 API·웹 UI·백엔드 미구현

- Flask는 requirements에만 있고 애플리케이션 코드가 없습니다.
- `backend/`, `templates/`, `web/` 등 README가 언급하는 디렉토리가 없습니다.
- 내선·회의실·CDR 관리 API, 인증, 권한, 라이선스 관리가 모두 미구현입니다.
- 클라이언트 저장소도 문서만 있고 React/SIP.js/Flutter 코드는 없습니다.

#### F-10. 운영·관측·백업 체계 부재

- 헬스체크, 메트릭(Prometheus 등), 로그 로테이션, 알림, CDR 보존 정책이 없습니다.
- 컨테이너 재시작 정책은 설계에 있으나 실제 Compose가 없습니다.
- 백업·복구(RPO/RTO), NAS 장애 대응, 설정 버전 관리가 없습니다.
- SIP/RTP 품질(RTCP, jitter, packet loss, MOS) 수집 계획이 없습니다.

#### F-11. 문서 무결성 문제

- 2026-10-29 리뷰 보고서는 존재하지 않는 파일을 “완료”로 평가했습니다. 이는 문서 기반 의사결정의 신뢰도를 떨어뜨립니다.
- README의 프로젝트 트리에 실제로 없는 `backend/`, `templates/`, `tests/`, `config_v0_1.py`, `cache_v5/`, `db/`, `csv/`, `bak/`, `Docs/` 등이 포함되어 있습니다.
- `wiki/03_Guides/usage-guide.md`는 `github.com/microdit/kibal.git`을 clone하라고 안내하지만 실제 저장소는 `SmartCC_Kibal`입니다.
- `wiki/04_Prompts/work-commands.md`의 remote URL(`kibal.git`, `nas2/kibal.git`)도 실제와 다릅니다.
- `docs/작업지시서.md`에 “Kiabal” 오타, `작업지사.md` 오타가 보입니다.
- 로컬과 origin의 문서 버전이 달라 동일 문서를 두고 서로 다른 결론이 나올 수 있습니다.

#### F-12. Git 자동화의 안전장치 부족

- `git-sync.sh`가 `git add -A`로 전체를 스테이징하고 모든 remote에 push합니다.
- 커밋 전 테스트·비밀값 스캔·린트가 없습니다.
- `deploy_to_nas_v2.sh`를 호출하지만 해당 파일이 없습니다.
- 자동 커밋 메시지 생성기가 문서/코드를 추정 분류하므로, 중요한 변경이 `chore`로 뭉개질 수 있습니다.
- `.gitignore`가 `.dockerignore`를 무시하는 설정은 Docker 빌드 재현성에 역효과입니다.

### 4.3 P2 — 개선 권고

| ID | 항목 | 권고 |
|----|------|------|
| F-13 | 성능·용량 미검증 | 4/10/30명 단계별 실측, 100명은 전용 SFU 검토 |
| F-14 | Windows 스크립트 검증 부재 | `git-sync.bat` CP949/모지바케, 경로·옵션 테스트 필요 |
| F-15 | 한글 경로·파일명 | Windows/NAS/Docker 빌드 컨텍스트에서 인코딩·경로 이슈 점검 |
| F-16 | Docker 엔진 구버전 | Docker Desktop/Engine/Compose 업데이트 및 이미지 스캔 |
| F-17 | 라이선스 문서와 산출물 불일치 | GPL 소스 제공, COPYING, SBOM, THIRD_PARTY_NOTICES 실제 패키지화 |
| F-18 | CI/CD·릴리스 부재 | GitHub Actions, 이미지 서명/digest, 버전 태그, 변경 이력 |
| F-19 | 클라이언트·서버 계약 부재 | SIP/API/미디어 인터페이스 계약서와 버전 호환성 정의 |
| F-20 | 문서 중복·단일 출처 부재 | `CLAUDE.md`, `AGENTS.md`, `작업지시서`, Wiki의 단일 기준 문서 확정 |

---

## 5. 설계 문서 리뷰

### 5.1 아키텍처

**긍정적 평가**

- Asterisk 22 LTS + PJSIP + ConfBridge + H.264라는 기술 선택은 소규모 SIP 영상회의 MVP에 현실적입니다.
- SIP 신호와 미디어를 분리하고, 향후 미디어 서버 확장을 고려한 방향은 타당합니다.
- 단계별 로드맵(1:1 → 4명 → 10명 → 30명 → 100명)은 의사결정에 유용합니다.

**보완 필요**

- “Asterisk ConfBridge SFU로 100명”은 현실성이 낮습니다. 30명 이상은 전용 SFU(예: Janus, mediasoup, Jitsi Videobridge 등) 또는 계층형 구조를 별도 검토해야 합니다.
- 1:1 통화는 Asterisk bridge로 충분하지만, 녹음·NAT·WebRTC를 고려하면 `direct_media=no` 정책과 미디어 경로 설계가 필요합니다.
- SIP 하드폰과 WebRTC 클라이언트가 혼재하면 코덱·프로파일·암호화 협상이 복잡해집니다. MVP는 “동일 코덱 H.264” 또는 “하드폰 우선”으로 범위를 고정하는 편이 안전합니다.
- H.264 특허·라이선스는 Asterisk GPL과 별개입니다. 상용 배포 전 코덱 정책을 명확히 해야 합니다.

### 5.2 Docker 배포 설계

**긍정적 평가**

- 컨테이너 분리(Asterisk/API/Web), 볼륨, 단계별 배포 개념은 방향성이 좋습니다.
- NAS 배포를 염두에 둔 것은 PRD 현실성 측면에서 적절합니다.

**보완 필요**

- `asterisk:22-latest` 이미지 태그는 실제 존재·유지보수·서명 여부를 확인하고, 가능하면 직접 빌드한 이미지를 digest로 고정해야 합니다.
- Linux host network를 기본으로 하되, macOS Docker Desktop에서는 동일 전략을 쓰지 말아야 합니다.
- RTP 범위는 10,000개 포트를 모두 열기보다 1,000~2,000개 수준으로 줄이고, 동시 통화 수에 맞춰 산정해야 합니다.
- NAS의 CPU 아키텍처(x86_64/ARM), Docker 버전, host network 지원, 방화벽, 포트 충돌을 사전 확인해야 합니다.
- API/Web은 MVP에서 제외하고, Asterisk 단일 컨테이너부터 검증하는 것이 좋습니다.

### 5.3 SIP 클라이언트 설계

- SIP REGISTER → 401 → 재등록 → 200 OK 흐름은 적절합니다.
- SDP 예시는 오디오 Opus + 비디오 H.264 구조로 이해 가능하지만, 실제 Asterisk 설정과 단말 협상 결과로 검증해야 합니다.
- ConfBridge 설정 예시는 실제 문법과 다를 수 있으므로, `confbridge.conf`의 bridge/user 프로필을 공식 문서 기준으로 다시 작성해야 합니다.
- WebRTC를 목표로 한다면 SIP.js 예시의 `wsServers`만으로는 부족합니다. WSS 인증서, ICE 서버, DTLS-SRTP, TURN 자격 증명, 브라우저 권한·HTTPS 제약을 함께 설계해야 합니다.
- 모바일 브라우저는 백그라운드·화면 잠금 시 세션이 제한되므로, “전화 앱 수준 상시 수신” 요구가 있으면 네이티브 앱 또는 푸시 설계가 별도로 필요합니다.

### 5.4 라이선스 문서

- GPLv2와 상용 라이선스의 차이, ARI/AMI/AGI 독립 프로그램 예외, 고객사 납품 시 의무를 설명한 방향은 적절합니다.
- 다만 현재 저장소에는 `COPYING`, `THIRD_PARTY_NOTICES`, `SBOM`, GPL 소스 제공 안내, 이미지 digest가 없습니다. 문서만으로는 컴플라이언스가 완성되지 않습니다.
- H.264 코덱 특허, SIP 단말 펌웨어, Docker 베이스 이미지, coturn 등 제3자 라이선스를 목록화해야 합니다.
- 고객사 납품형인지 SaaS인지에 따라 의무가 달라지므로, 사업 모델을 먼저 확정한 뒤 법률 검토를 받아야 합니다.

### 5.5 Knowledge OS·문서 체계

- 9-Layer Wiki, Git 로그, Vector DB 검색이라는 방향은 유지보수성 측면에서 좋습니다.
- 그러나 로컬과 origin의 문서 버전이 다르고, 06~09 디렉토리가 로컬에 없으며, Vector DB는 gitignore로 저장소에 없습니다.
- “문서 완료”와 “구현 완료”를 분리하는 검증 게이트가 필요합니다. 예: `docs/보고서`에 증거 링크(커밋, 로그, 캡처, 테스트 결과)를 첨부하지 않으면 완료로 인정하지 않는 규칙.
- 2026-10-29 리뷰 보고서는 “파일이 존재한다”는 전제로 작성되었으므로, 현재 상태 기준으로 **재검토 또는 폐기 표시**가 필요합니다.

---

## 6. Docker·인프라 구축 계획

### 6.1 현재 환경의 핵심 제약

1. **macOS Docker Desktop의 host network 한계**
   - Linux의 `network_mode: host`처럼 LAN에 직접 노출되지 않습니다.
   - SIP/RTP는 Docker Desktop VM의 NAT를 거치므로, 실제 SIP 단말과의 양방향 미디어 검증에 부적합합니다.
2. **Kibal 전용 이미지·컨테이너 부재**
   - Asterisk, coturn, Nginx/Caddy, API, Web 이미지가 모두 없습니다.
3. **Docker Engine 구버전**
   - 20.10.22는 최신 보안·기능 기준이 아닙니다. 업데이트 가능 여부를 확인해야 합니다.
4. **NAS PRD 사양 미확인**
   - CPU, 메모리, 디스크, NIC, Docker 버전, host network 지원 여부가 설계에 반영되지 않았습니다.

### 6.2 필요한 이미지·컨테이너

| 구성 요소 | 권장 이미지/빌드 | MVP 포함 | 용도 | 현재 상태 |
|-----------|------------------|----------|------|-----------|
| Asterisk PBX/SFU | `kibal/asterisk:22` (Debian 기반 직접 빌드, digest 고정) | **필수** | SIP 등록, 1:1, ConfBridge | 없음 |
| 테스트 도구 | `sipp`, `sngrep`, `ffmpeg` (로컬 또는 사이드카) | **필수** | REGISTER/INVITE/RTP 검증 | 없음 |
| TURN/STUN | `coturn/coturn` (버전 고정) | 2단계 | NAT/WebRTC 미디어 릴레이 | 없음 |
| 리버스 프록시 | `nginx:1.27-alpine` 또는 Caddy | 2단계 | HTTPS/WSS, 정적 파일 | 없음 |
| 관리 API | `python:3.11-slim` 기반 자체 이미지 | 3단계 | Flask/ARI, 내선·회의실 관리 | 없음 |
| 웹 클라이언트 | Node 빌드 후 Nginx 정적 서빙 | 3단계 | React + SIP.js | 없음 |
| 선택: DB | `postgres:16-alpine` | 3단계 이후 | 설정·이력·사용자 | 없음 |
| 선택: 캐시 | `redis:7-alpine` | 3단계 이후 | 세션·큐 | 없음 |

> **중요:** MVP에서 위 구성 요소를 한꺼번에 도입하지 말고, `Asterisk + 테스트 도구`만으로 T01~T05를 통과한 뒤 단계적으로 추가해야 합니다.

### 6.3 권장 저장소 구조

```text
server/
├── compose.yaml
├── .env.example
├── .dockerignore
├── README.md
├── asterisk/
│   ├── Dockerfile
│   └── config/
│       ├── asterisk.conf
│       ├── modules.conf
│       ├── pjsip.conf
│       ├── extensions.conf
│       ├── confbridge.conf
│       ├── rtp.conf
│       ├── cdr.conf
│       └── logger.conf
├── scripts/
│   ├── start.sh
│   ├── stop.sh
│   ├── status.sh
│   ├── verify.sh
│   ├── logs.sh
│   └── capture.sh
├── tests/
│   ├── config/
│   ├── sip/
│   └── media/
└── data/
    ├── logs/
    ├── spool/
    └── cdr/
```

### 6.4 최소 Compose 예시 (권장안, 아직 적용하지 않음)

> Linux 호스트 기준입니다. macOS Docker Desktop에서는 이 host network 구성을 그대로 사용하지 마십시오.

```yaml
services:
  asterisk:
    build:
      context: ./asterisk
    image: kibal/asterisk:22
    container_name: kibal-asterisk
    network_mode: host
    env_file:
      - .env
    volumes:
      - ./asterisk/config:/etc/asterisk:ro
      - ./data/logs:/var/log/asterisk
      - ./data/spool:/var/spool/asterisk
      - ./data/cdr:/var/log/asterisk/cdr
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "asterisk -rx 'core show uptime' | grep -q 'System uptime'"]
      interval: 30s
      timeout: 5s
      retries: 3
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - NET_RAW
    # Asterisk가 필요한 권한만 별도 검토하여 추가
```

**추가 권장:**

- `.env.example`에 내선 비밀번호 placeholder, 외부 IP, RTP 범위, TURN 자격 증명 항목을 정의
- 실제 비밀번호는 `.env`/Docker secret/외부 시크릿 저장소로 분리
- `.dockerignore`에 `.git`, `docs`, `wiki`, `venv*`, `vector_db`, `*.log`, `*.db` 포함
- 이미지 빌드 시 `--pull`, `--no-cache`, digest pin, Trivy 스캔 적용
- Compose에 리소스 제한(`cpus`, `mem_limit`)과 로그 드라이버 `json-file` rotation 설정

### 6.5 Asterisk 이미지 빌드 시 고려사항

- Debian 12 slim 기반 소스 빌드 또는 신뢰 가능한 공식/커뮤니티 이미지 사용
- 빌드 의존성: `build-essential`, `libssl-dev`, `libncurses-dev`, `libxml2-dev`, `libsqlite3-dev`, `libjansson-dev`, `libedit-dev`, `uuid-dev`, `libsrtp2-dev`, `libopus-dev`, `pkg-config`, `wget`, `ca-certificates` 등
- Asterisk 버전·소스 tarball checksum 고정, `make menuselect`로 필요한 모듈만 포함
- `chan_pjsip`, `app_confbridge`, `res_pjsip*`, `codec_*`, `format_*` 모듈 로딩 확인
- H.264/VP8 지원 모듈과 WebRTC용 `res_srtp`, `res_http_websocket`, `res_pjsip_transport_websocket` 등 포함 여부 확인
- 이미지에 `COPYING`, 라이선스 고지, 소스 제공 안내 포함
- 비root 사용자, 읽기 전용 루트파일시스템(가능한 범위), 최소 권한으로 실행

### 6.6 네트워크·NAT 전략

| 환경 | 권장 방식 | 비고 |
|------|-----------|------|
| Ubuntu 24.04 Linux | host network + 방화벽 | SIP/RTP 양방향 검증에 가장 단순 |
| Synology NAS | Docker host network 가능 여부 확인, 불가 시 macvlan/별도 Linux VM | NAS 모델·DSM 버전별 차이 큼 |
| macOS 개발 | Linux VM(UTM/Multipass 등) 또는 원격 Linux 사용 | Docker Desktop host network 의존 금지 |
| 외부망 | SBC/방화벽, `external_media_address`, `external_signaling_address`, TURN | 포트 최소화, ACL, TLS/SRTP |
| WebRTC | WSS + ICE + DTLS-SRTP + coturn | HTTPS 인증서 필수 |

**PJSIP NAT 핵심 옵션(검증 필요):**

- `external_media_address`, `external_signaling_address`
- `local_net`, `rewrite_contact`, `rtp_symmetric`, `force_rport`
- WebRTC endpoint: `webrtc=yes`, `ice_support=yes`, `media_use_received_transport=yes`, `dtls_auto_generate_cert=yes` 등
- `direct_media=no` (NAT/녹음/WebRTC 환경)

### 6.7 스토리지·백업

- CDR은 CSV와 DB 중 하나로 단일화하고, 보존 기간·개인정보 마스킹 정책을 정의
- Asterisk 설정·CDR·로그를 NAS 볼륨에 두되, 컨테이너 재생성 시 유실되지 않도록 명시적 볼륨 사용
- 일일 백업, 주간 복구 리허설, 설정 버전 태그, RPO/RTO 정의
- 로그 로테이션(`logrotate` 또는 Docker logging driver) 필수

---

## 7. 성능·용량 산정

### 7.1 산정 가정

- 720p H.264 영상 1.5 Mbps/스트림
- Opus 오디오 64~96 kbps/스트림
- 패킷 오버헤드 약 10%
- SFU는 트랜스코딩 없이 포워딩한다고 가정
- 서버 egress ≈ `N × (N-1) × video bitrate`
- 실제 값은 단말·해상도·프레임·키프레임·네트워크에 따라 크게 달라짐

### 7.2 대략적 용량 모델

| 참가자 | 수신 스트림 수 | 영상 egress(추정) | 오디오 포함 총 egress(추정) | CPU(추정) | 메모리(추정) | 판단 |
|--------|----------------|-------------------|------------------------------|-----------|--------------|------|
| 2 (1:1) | 2 | 약 3 Mbps | 약 3.2 Mbps | < 0.5 vCPU | < 256 MB | 문제 없음 |
| 4 | 12 | 약 18 Mbps | 약 19 Mbps | 1~2 vCPU | 0.5~1 GB | MVP 적합 |
| 10 | 90 | 약 135 Mbps | 약 142 Mbps | 2~4 vCPU | 1~2 GB | 1GbE에서 검증 필요 |
| 30 | 870 | 약 1.3 Gbps | 약 1.4 Gbps | 4~8+ vCPU | 3~6 GB | 10GbE/전용 SFU 검토 |
| 100 | 9,900 | 약 14.9 Gbps | 약 15.6 Gbps | 현실적이지 않음 | - | Asterisk 단일 서버 불가 |

> 위 수치는 **설계 검토용 추정**이며, 실제 벤치마크 결과가 아닙니다. 특히 30명 이상은 반드시 실측해야 합니다.

### 7.3 병목 지점

1. **서버 egress 대역폭**: 참가자 수의 제곱에 비례합니다. 30명만 되어도 1Gbps에 근접합니다.
2. **패킷 처리량**: 720p 30fps 스트림은 초당 약 1,000패킷 수준입니다. 30명 규모에서 수십만 pps, 100명은 수백만~수천만 pps가 되어 커널·NIC·가상화 계층이 병목입니다.
3. **CPU**: 포워딩은 트랜스코딩보다 가볍지만, 패킷 복사·암호화(SRTP/DTLS)·NAT·컨테이너 오버헤드가 누적됩니다. 트랜스코딩이 발생하면 CPU가 수 배 증가합니다.
4. **메모리·컨텍스트 스위치**: 참가자·채널·RTP 세션 수에 비례합니다.
5. **Docker Desktop 가상화**: macOS Docker Desktop은 Linux VM을 거치므로 호스트 네트워크·패킷 처리 성능이 Linux 대비 불리합니다.
6. **NAS CPU**: Synology NAS는 모델에 따라 CPU가 약하고, 영상 SFU에 최적화되어 있지 않습니다. PRD 사양 확인이 필수입니다.

### 7.4 벤치마크 계획

| 시험 | 도구 | 측정 항목 | 합격 기준(예시) |
|------|------|-----------|------------------|
| SIP 등록 부하 | SIPp | REGISTER 성공률, 응답시간 | 100% 성공, p95 < 500ms |
| 1:1 영상 | 실제 단말/ffmpeg | 호 설정, 영상 표시, 지연 | 2초 내 연결, 3초 내 영상 |
| 다자간 SFU | 실제 단말 3~4대 | 다중 영상 표시, 음성 믹싱 | 전 참가자 영상/음성 확인 |
| 네트워크 | iperf3, tc netem | 대역폭, 손실, 지터 | 손실 < 1%, 지터 < 30ms |
| 장시간 | 24~72시간 soak | 메모리 누수, 재등록, CDR | 크래시 0, 누수 추세 없음 |
| 보안 | Trivy, nmap, SIP 스캔 | 취약점, 오픈 포트 | Critical/High 0 |
| 복구 | 백업/복원 | RTO/RPO | 목표 시간 내 복구 |

---

## 8. 테스트 결과 및 자체 검증

### 8.1 이번 리뷰에서 실제 수행한 검증

| 검증 항목 | 명령/방법 | 결과 | 판정 |
|-----------|-----------|------|------|
| Python 문법 | `python3 -m py_compile` (5개 파일) | 오류 없음 | PASS |
| 셸 문법 | `bash -n scripts/*.sh` | 오류 없음 | PASS |
| ChromaDB 인덱싱 | `python3 scripts/index_wiki.py --stats` | 6개 문서 / 41개 청크 | PASS |
| 의미 검색 | `--search "SIP 영상통화"` | 0.625 / 0.603 / 0.537 | PASS |
| 테스트 수집 | `python3 -m pytest -q` | no tests ran (0개) | FAIL(테스트 없음) |
| Compose 검증 | `docker compose config` | 설정 파일 없음 | FAIL |
| Docker 상태 | `docker version/info` | Desktop 4.16.1, Engine 20.10.22 | PASS(환경 확인) |
| Kibal 컨테이너 | `docker ps -a` | Kibal 컨테이너 없음 | FAIL(미구축) |
| Asterisk 이미지 | `docker images` | Asterisk 이미지 없음 | FAIL(미구축) |
| SIP 포트 | `lsof -iUDP:5060` | 리스너 없음 | FAIL(미기동) |
| Asterisk 바이너리 | `which asterisk` | 없음 | FAIL(미설치) |
| Git 원격 | `git ls-remote origin` | origin/main `7d0f7de` | PASS(접속) |
| Git 동기화 | `git rev-list --left-right --count` | 3 / 0 (뒤처짐) | FAIL |
| Remote 구성 | `git remote -v` | origin만 존재 | FAIL(3-way 아님) |

> ChromaDB 검증 과정에서 `vector_db/`가 생성되었으나, 검토 후 삭제하여 작업 트리를 원상 복구했습니다. `__pycache__`도 제거했습니다.

### 8.2 기능 테스트 매트릭스

| ID | 테스트 | 상태 | 비고 |
|----|--------|------|------|
| T01 | SIP 등록 (4개 내선) | 미실행 | Asterisk 기동 선행 필요 |
| T02 | 1:1 음성통화 | 미실행 | - |
| T03 | 1:1 영상통화 (H.264) | 미실행 | 핵심 가설 |
| T04 | 3자 음성회의 | 미실행 | - |
| T05 | 3자 SFU 영상회의 | 미실행 | 핵심 가설 |
| T06 | 4자 영상회의 | 미실행 | 단말 다중 영상 표시 확인 |
| T07 | 재접속 | 미실행 | REGISTER 만료·재등록 |
| T08 | 통화 기록 (CDR) | 미실행 | CSV/SQLite 단일화 필요 |
| T09 | NAT/TURN | 미실행 | 외부망 확장 시 |
| T10 | 보안(TLS/SRTP) | 미실행 | 운영 전 필수 |
| T11 | 24시간 soak | 미실행 | 안정성 |
| T12 | 백업/복구 | 미실행 | 운영 전 필수 |

### 8.3 테스트 피라미드 권고

1. **Unit**
   - 설정 파일 파서/검증기
   - 내선·회의실·비밀번호 검증 로직
   - Dialplan 문법 검사
   - API 응답 스키마
2. **Integration**
   - `docker compose up` 후 모듈 로딩 확인
   - SIPp로 REGISTER/INVITE 시나리오
   - CDR 생성 확인
   - 헬스체크·재시작 정책
3. **E2E**
   - 실제 SIP 영상전화기 1:1
   - 3~4자 ConfBridge
   - 재등록·장애 복구
4. **Non-functional**
   - 부하·soak·NAT·TLS/SRTP·보안 스캔·백업 복구

### 8.4 CI 최소 기준

- `python -m py_compile`, `pytest`
- `shellcheck` (셸 스크립트)
- `hadolint` (Dockerfile)
- `docker compose config`
- `trivy` 이미지 스캔
- 비밀값 스캔(`gitleaks` 등)
- 문서 링크 검사(깨진 내부 링크)
- `main` 브랜치 보호 및 PR 리뷰

---

## 9. 보안·컴플라이언스 리뷰

### 9.1 보안 체크리스트

| 항목 | 현재 | 권고 | 우선순위 |
|------|------|------|----------|
| SIP 비밀번호 | 평문 예시 | `.env`/secret 분리, 강력한 비밀번호, 정기 교체 | P0 |
| SIP 접근 제어 | 없음 | ACL, fail2ban, rate limit, 익명 호출 차단 | P0 |
| TLS/SRTP | 미구현 | SIPS/WSS, DTLS-SRTP, 인증서 관리 | P1 |
| 웹/API 인증 | 없음 | 세션/토큰, RBAC, 감사 로그 | P1 |
| ARI/AMI 보안 | 없음 | TLS, 계정 최소 권한, IP 제한 | P1 |
| 컨테이너 권한 | 미정 | 비root, cap_drop, no-new-privileges, read-only | P1 |
| 시크릿 관리 | 없음 | Docker secret/Vault/외부 저장소 | P1 |
| 로그 개인정보 | 미정 | CDR 마스킹, 보존 기간, 접근 통제 | P1 |
| 취약점 스캔 | 없음 | Trivy/Grype, 정기 업데이트 | P1 |
| 백업 암호화 | 없음 | 암호화 백업, 복구 리허설 | P2 |
| 네트워크 분리 | 없음 | DMZ/내부망 분리, 최소 포트 | P2 |

### 9.2 GPL·라이선스

- Asterisk GPLv2 의무를 실제 패키지에 반영해야 합니다.
  - `COPYING` 포함
  - 배포 바이너리에 대응하는 소스 제공 또는 서면 제안
  - 수정 시 수정 소스 포함
  - `THIRD_PARTY_NOTICES.md`, `SBOM.json`, 이미지 digest, 소스 버전 명시
- ARI/AMI/AGI로 제어하는 독립 애플리케이션은 별도 라이선스로 개발할 수 있다는 문서 설명은 타당하나, 결합 방식에 대한 법률 검토가 필요합니다.
- H.264는 Asterisk GPL과 별개로 특허·코덱 라이선스 검토가 필요합니다. 내부 사용과 고객 배포를 구분해야 합니다.
- SIP 단말 펌웨어, coturn, Nginx, React, SIP.js 등 제3자 라이선스를 목록화해야 합니다.
- “Docker 이미지로 배포하면 GPL을 피할 수 있다”는 오해를 경계해야 합니다. 컨테이너 분리는 라이선스 의무를 자동 면제하지 않습니다.

---

## 10. 미진한 내용·문서 정합성

### 10.1 저장소에 없는 핵심 산출물

| 산출물 | 상태 | 영향 |
|--------|------|------|
| `compose.yaml` / `docker-compose.yml` | 없음 | 실행 불가 |
| `Dockerfile` / `Dockerfile.api` | 없음 | 이미지 빌드 불가 |
| `config/*` Asterisk 설정 | 없음 | PBX 설정 불가 |
| `scripts/start.sh`, `verify.sh`, `status.sh`, `capture.sh` | 없음 | 운영·검증 불가 |
| `.env.example` | 없음 | 설정 재현 불가 |
| `.dockerignore` | 없음 | 빌드 컨텍스트 오염 |
| `tests/` | 없음 | 회귀 검증 불가 |
| `deploy_to_nas_v2.sh` | 없음 | `git-sync.sh --deploy` 실패 |
| `daily_ohlcv_update.py` | 없음 | 문서 명령 오류 |
| `wiki_agent.py` | 없음 | 자동 문서화 기능 비활성 |
| Flask 관리 API | 없음 | 관리 기능 없음 |
| Web 클라이언트 | 없음 | 브라우저 접속 불가 |
| `venv_kibal/` | 없음 | 문서 주장과 불일치 |

### 10.2 깨진 참조·명칭 불일치

- `README.md` → `Docs/작업지령서.md`, `Docs/설계초안_v1.0.md` (실제 경로와 다름, `docs/` 소문자)
- `README.md` → `backend/`, `templates/`, `tests/`, `config_v0_1.py`, `cache_v5/`, `db/`, `csv/`, `bak/` (없음)
- `wiki/03_Guides/usage-guide.md` → `github.com/microdit/kibal.git` (실제 `SmartCC_Kibal`)
- `wiki/04_Prompts/work-commands.md` → `github.com/microdit/kibal.git`, `nas2/.../kibal.git` (실제와 다름)
- `CLAUDE.md` → `github/dev/prd` 3-way (현재 `origin`만)
- `CLAUDE.md` → `docs/AGENTS.md` (로컬에 없음, origin에만 존재)
- `docs/작업지시서.md` → “Kiabal”, “작업지사.md” 오타
- `wiki/02_Design/sip-client.md` → ConfBridge 설정 예시 문법 불확실
- `wiki/02_Design/docker-setup.md` → `asterisk:22-latest`, `./web`, `Dockerfile.api` 미존재
- `.gitignore` → `.dockerignore` 무시 (Docker 산출물 커밋 불가)
- `docs/보고서/` → 리뷰 보고서를 저장할 디렉토리만 있고 기존 보고서 없음

### 10.3 Knowledge OS 정합성

- 로컬 Wiki는 01~05만 있고, origin에는 06~09가 있습니다. 로컬 동기화가 선행되어야 합니다.
- `docs/AGENTS.md`와 `docs/작업지시서.md`는 origin에만 있으므로, 로컬 작업자는 최신 지침을 보지 못할 수 있습니다.
- Vector DB는 gitignore되어 있어 팀원이 동일 검색 결과를 재현하려면 재인덱싱이 필요합니다. 인덱싱 절차·모델 버전·청크 수를 문서화해야 합니다.
- “문서 완료” 판정 기준이 없어, 실제 산출물이 없어도 완료로 기록되는 문제가 발생했습니다. 증거 기반 완료 기준(DoD)이 필요합니다.

---

## 11. 조치 계획 (Roadmap)

### Phase 0 — 정리·기준 확정 (D0~D2)

| 작업 | 산출물 | 완료 기준 |
|------|--------|-----------|
| 작업 트리 백업 및 정리 | 백업 태그/브랜치 | 미커밋 변경 처리 방침 확정 |
| `origin/main` 동기화 | 최신 HEAD | `git status` clean, 3-way 여부 재정의 |
| Remote·URL 정합성 수정 | 문서/스크립트 | 실제 URL과 문서 일치 |
| 범위 고정 | MVP 정의서 | “Asterisk 1대 + 4내선 + 1:1 + 4자 SFU”로 한정 |
| 검증 환경 확정 | Ubuntu 24.04/NAS/VM | Linux host network 가능 확인 |

### Phase 1 — 실행 가능한 MVP (W1~W2)

| 작업 | 산출물 | 완료 기준 |
|------|--------|-----------|
| MVP 파일 커밋 | Compose, Dockerfile, config, scripts, .env.example, .dockerignore | `docker compose config` 성공 |
| Asterisk 이미지 빌드 | `kibal/asterisk:22` | 이미지 빌드·기동, 모듈 로딩 |
| T01 SIP 등록 | 검증 로그/캡처 | 1001~1004 REGISTER 성공 |
| T02/T03 1:1 | SIP/SDP/RTP 캡처 | 음성·영상 양방향 확인 |
| 기본 CI | GitHub Actions | py_compile, shellcheck, compose config 통과 |
| 보안 최소선 | secrets 분리, ACL 초안 | 평문 비밀번호 제거 |

### Phase 2 — 다자간 회의 (W3~W4)

| 작업 | 산출물 | 완료 기준 |
|------|--------|-----------|
| T04/T05 3자 회의 | ConfBridge 설정·로그 | 음성 믹싱·영상 전달 확인 |
| T06 4자 회의 | 다중 영상 표시 결과 | 단말별 표시 한계 문서화 |
| T07/T08 | 재등록·CDR | 재등록 성공, CDR 저장 확인 |
| 모니터링 최소 | 헬스체크·로그 로테이션 | 장애 감지 가능 |
| 성능 1차 | 4자 부하 측정 | 대역폭·CPU 기준선 확보 |

### Phase 3 — WebRTC·운영 기반 (W5~W8)

| 작업 | 산출물 | 완료 기준 |
|------|--------|-----------|
| WSS/HTTPS | Nginx/Caddy + 인증서 | 브라우저 WSS 연결 |
| TURN | coturn | 외부망 1:1 영상 성공 |
| TLS/SRTP | PJSIP/TURN 설정 | 암호화 통화 확인 |
| 관리 API | Flask/ARI 최소 기능 | 내선·회의실 조회 |
| Web 클라이언트 | React + SIP.js | 로그인·1:1·회의실 |
| 10명 시험 | 부하 결과 | 목표 지표 충족 |

### Phase 4 — 제품화·납품 준비 (W9~W12)

| 작업 | 산출물 | 완료 기준 |
|------|--------|-----------|
| 30명 벤치마크 | 성능 보고서 | 병목·한계 명확화 |
| 고가용성·백업 | 이중화/백업 절차 | 복구 리허설 성공 |
| GPL/SBOM 패키지 | COPYING, notices, SBOM | 법률 검토 통과 |
| NAS 배포 | 설치·업그레이드 스크립트 | PRD 재현 성공 |
| 릴리스 | 태그·이미지 digest | 재현 가능한 릴리스 |

### Phase 5 — 100명 확장 검토 (별도)

- Asterisk 단일 서버로 100명을 처리하려 하지 말고, 전용 SFU(예: Janus, mediasoup, Jitsi Videobridge) 또는 계층형/지역 분산 구조를 비교 검토합니다.
- simulcast/SVC, 선택적 구독, 화면 분할, 대역폭 적응, 녹화·스트리밍 요구를 함께 정의합니다.

---

## 12. 종합 결론 및 자문 의견

### 12.1 결론

- **문서·아키텍처 방향성:** 조건부 적합. Asterisk 22 + PJSIP + ConfBridge + H.264는 4명 이하 MVP에 현실적입니다.
- **현재 실행 가능성:** 부적합. 저장소에 실행 산출물이 없고, 검증된 컨테이너·SIP 통화가 없습니다.
- **운영·납품 준비:** 부적합. 보안·모니터링·백업·라이선스 산출물·CI/CD가 없습니다.
- **최종 판단:** **“MVP 착수는 승인 가능, 운영 배포는 보류(Conditional Go / No-Go for Production)”**

### 12.2 자문 의견

> 지금 필요한 것은 문서를 더 늘리는 일이 아니라, **작은 실행 단위를 실제로 돌려 증거를 남기는 일**입니다.  
> 2주 안에 “Asterisk 컨테이너 기동 + 4내선 등록 + 1:1 영상통화 + 3자 SFU”를 증거(로그·캡처·영상)와 함께 완료하면 프로젝트는 정상 궤도에 올릴 수 있습니다.  
> 반대로 이 증거 없이 WebRTC·100명·상용 납품 문서를 먼저 확장하면, 현재의 “문서상 완료·실제 미검증” 문제가 반복될 가능성이 높습니다.

### 12.3 의사결정 게이트

| 게이트 | 통과 조건 | 미통과 시 |
|--------|-----------|-----------|
| G1. 저장소 기준 확정 | origin/main 동기화, 문서·URL 정합성 | 개발 중단, 기준 재설정 |
| G2. MVP 실행 | 이미지 빌드, 4내선 REGISTER, 1:1 영상 | 원인 분석 후 재시도 |
| G3. 다자간 | 3~4자 SFU 음성·영상 | 단말/코덱/설정 재검증 |
| G4. 운영 준비 | 보안·백업·모니터링·CI | PRD 배포 보류 |
| G5. 상용 납품 | GPL/SBOM/법률 검토 완료 | 납품 보류 |

---

## 부록 A. 자체 검증 명령·결과 요약

```text
$ git status --short
 M scripts/git-pull.sh
?? docs/준비문서/

$ git rev-list --left-right --count origin/main...HEAD
3	0

$ git remote -v
origin  https://github.com/microdit/SmartCC_Kibal.git (fetch)
origin  https://github.com/microdit/SmartCC_Kibal.git (push)

$ git ls-remote --heads origin
7d0f7de... refs/heads/main

$ docker version
Client: 20.10.22
Server: Docker Desktop 4.16.1 (95567), Engine 20.10.22

$ docker compose version
Docker Compose version v2.15.1

$ docker info --format '{{.OperatingSystem}} | {{.Architecture}} | CPUs={{.NCPU}} | Mem={{.MemTotal}}'
Docker Desktop | x86_64 | CPUs=8 | Mem=8240328704

$ docker ps -a
(3개 SmartCodexStudio 컨테이너, Kibal 없음)

$ docker images
(8개 이미지, Asterisk 없음)

$ python3 --version
Python 3.9.6

$ python3 -c "import chromadb; print(chromadb.__version__)"
1.5.9

$ python3 -m py_compile agent_wiki_vector.py scripts/index_wiki.py scripts/log.py scripts/generate-commit-msg.py scripts/pick_branch.py
(pass)

$ bash -n scripts/git-pull.sh scripts/git-sync.sh
(pass)

$ python3 scripts/index_wiki.py --stats
[index] Done: 6 files, 41 chunks indexed
[index] Stats: 41 chunks from 6 documents

$ python3 scripts/index_wiki.py --search "SIP 영상통화" --n 3
[0.625] wiki/01_Projects/project-brief.md
[0.603] wiki/05_Decisions/ADR-001.md
[0.537] wiki/05_Decisions/ADR-001.md

$ python3 -m pytest -q
no tests ran in 0.01s

$ docker compose config
no configuration file provided: not found

$ which asterisk
(not found)

$ lsof -nP -iUDP:5060
(no listener)

$ ls compose.yaml Dockerfile docker-compose.yml
(not found)
```

---

## 부록 B. 권장 최소 파일 트리

```text
SmartCC_Kibal/
├── server/
│   ├── compose.yaml
│   ├── .env.example
│   ├── .dockerignore
│   ├── asterisk/
│   │   ├── Dockerfile
│   │   └── config/
│   │       ├── asterisk.conf
│   │       ├── modules.conf
│   │       ├── pjsip.conf
│   │       ├── extensions.conf
│   │       ├── confbridge.conf
│   │       ├── rtp.conf
│   │       ├── cdr.conf
│   │       └── logger.conf
│   ├── scripts/
│   │   ├── start.sh
│   │   ├── stop.sh
│   │   ├── status.sh
│   │   ├── verify.sh
│   │   ├── logs.sh
│   │   └── capture.sh
│   └── tests/
│       ├── config/
│       ├── sip/
│       └── media/
├── docs/
├── wiki/
└── (기존 자동화 스크립트)
```

---

## 부록 C. 리스크 등록부

| ID | 리스크 | 가능성 | 영향 | 대응 |
|----|--------|--------|------|------|
| R-01 | 실행 산출물 부재로 일정 지연 | 높음 | 높음 | Phase 1에서 MVP 파일 우선 커밋 |
| R-02 | macOS Docker 네트워크로 SIP 검증 실패 | 높음 | 높음 | Linux 호스트/VM에서 검증 |
| R-03 | 단말 다중 영상 표시 미지원 | 중간 | 높음 | T06에서 단말별 한계 문서화, 웹 클라이언트 대안 |
| R-04 | H.264 협상 실패/검은 화면 | 중간 | 높음 | SDP·프로파일·키프레임·RTP 캡처 분석 |
| R-05 | NAT/TURN 미구성으로 외부망 실패 | 중간 | 높음 | Phase 3에서 coturn·ICE 검증 |
| R-06 | NAS 성능 부족 | 중간 | 높음 | 사전 벤치마크, Linux 서버 대안 |
| R-07 | 100명 목표 달성 불가 | 높음 | 중간 | 전용 SFU 검토, 목표 재설정 |
| R-08 | GPL/코덱 라이선스 리스크 | 중간 | 높음 | SBOM·법률 검토·소스 제공 |
| R-09 | 문서·구현 불일치 재발 | 높음 | 중간 | 증거 기반 DoD, CI 문서 링크 검사 |
| R-10 | Git 자동화로 비밀값/대용량 커밋 | 중간 | 높음 | `git add -A` 제한, secret scan, 리뷰 |

---

## 부록 D. 검토 한계 및 후속 확인 사항

1. 이 보고서는 **로컬 저장소와 `origin/main` 문서를 읽기 전용으로 분석**한 결과입니다. 실제 PRD/NAS 환경은 확인하지 못했습니다.
2. Docker 이미지 빌드, SIP 단말 연결, 부하·보안 시험은 수행하지 않았습니다. 해당 항목은 “미검증”으로 간주해야 합니다.
3. `docs/준비문서/`는 로컬 미추적 문서로, origin/main에는 없습니다. 향후 기준 문서로 사용할 경우 커밋·버전 관리가 필요합니다.
4. 로컬과 origin의 문서가 다르므로, 후속 작업 전 `origin/main` 기준으로 동기화한 뒤 본 보고서의 파일 경로를 재확인해야 합니다.
5. Asterisk ConfBridge·PJSIP 설정 문법은 실제 버전(22 LTS) 문서와 `asterisk -rx` 검증으로 최종 확인해야 합니다.

---

**보고서 끝.**
