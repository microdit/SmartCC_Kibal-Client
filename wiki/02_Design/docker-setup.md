# Docker 배포 설계 (Docker Setup Design)

| 항목 | 내용 |
|------|------|
| **작성일** | 2026-10-29 |
| **버전** | v1.0 |
| **작성자** | microdit |
| **상태** | 작업중 |
| **관련** | [[docs/작업지시서]], [[wiki/02_Design/architecture]] |

## 1. 설계 배경

Kibal 프로젝트는 현재 DEV (macOS) 환경에서 Wiki/Vector DB/스크립트를 개발 중입니다.
향후 PRD (Synology NAS `192.168.11.2:4949`)로 배포하기 위해 **Docker 컨테이너 아키텍처**를 설계합니다.

## 2. 컨테이너 구조

### 2.1 컨테이너 목록

| 컨테이너 | 베이스 이미지 | 포트 | 설명 |
|----------|---------------|------|------|
| `kibal-asterisk` | `asterisk:22-latest` | 5060 (SIP), 10000-20000 (RTP) | Asterisk 22 LTS PBX 엔진 |
| `kibal-api` | `python:3.11-slim` | 8000 | Flask 관리 API (향후) |
| `kibal-web` | `nginx:alpine` | 80 | 웹 UI 정적 서빙 (향후) |

### 2.2 네트워크

```yaml
networks:
  kibal-net:
    driver: bridge
```

### 2.3 볼륨

| 컨테이너 | 호스트 경로 | 컨테이너 경로 | 용도 |
|----------|------------|---------------|------|
| kibal-asterisk | `./asterisk/etc` | `/etc/asterisk` | 설정 파일 |
| kibal-asterisk | `./asterisk/cdr` | `/var/log/asterisk/cdr` | CDR 로그 |
| kibal-asterisk | `./asterisk/conf` | `/var/spool/asterisk/confbridge` | 회의 설정 |
| kibal-api | `./vector_db` | `/app/vector_db` | ChromaDB 데이터 |
| kibal-api | `./wiki` | `/app/wiki` | Wiki 문서 |

## 3. Docker Compose

```yaml
version: "3.9"
services:
  asterisk:
    image: asterisk:22-latest
    container_name: kibal-asterisk
    ports:
      - "5060:5060/udp"
      - "10000-20000:10000-20000/udp"
    volumes:
      - ./asterisk/etc:/etc/asterisk
      - ./asterisk/cdr:/var/log/asterisk/cdr
      - ./asterisk/conf:/var/spool/asterisk/confbridge
    networks:
      - kibal-net
    restart: unless-stopped

  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    container_name: kibal-api
    ports:
      - "8000:8000"
    volumes:
      - ./vector_db:/app/vector_db
      - ./wiki:/app/wiki
    environment:
      - PYTHON_PATH=/app
    networks:
      - kibal-net
    restart: unless-stopped

  web:
    image: nginx:alpine
    container_name: kibal-web
    ports:
      - "80:80"
    volumes:
      - ./web:/usr/share/nginx/html:ro
    networks:
      - kibal-net
    restart: unless-stopped

networks:
  kibal-net:
    driver: bridge
```

## 4. Asterisk 컨테이너 빌드

### Dockerfile (향후 작업)

```dockerfile
FROM asterisk:22-latest
COPY ./asterisk/etc/ /etc/asterisk/
RUN chmod -R 755 /etc/asterisk
EXPOSE 5060/udp 10000-20000/udp
```

## 5. 배포 단계 (Stage)

| 단계 | 목표 | 컨테이너 | 비고 |
|------|------|----------|------|
| 1 | MVP (1:1 영상통화) | asterisk만 | 단일 컨테이너 |
| 2 | 기본 회의 | asterisk + confbridge | SFU 검증 |
| 3 | 관리 API | + kibal-api | Flask + ChromaDB |
| 4 | 웹 UI | + kibal-web | Nginx 정적 서빙 |
| 5 | NAS 배포 | docker-compose on NAS | `192.168.11.2:4949` |

## 6. 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `ASTERISK_VERSION` | `22` | Asterisk LTS 버전 |
| `SIP_PORT` | `5060` | SIP 신호 포트 |
| `RTP_MIN` | `10000` | RTP 시작 포트 |
| `RTP_MAX` | `20000` | RTP 종료 포트 |
| `API_PORT` | `8000` | Flask API 포트 |
| `WEB_PORT` | `80` | 웹 UI 포트 |

## 7. 검증 계획

| 테스트 | 방법 | 완료 |
|--------|------|------|
| D01 | `docker info` 확인 | ☐ |
| D02 | `docker images -a` 확인 | ☐ |
| D03 | `docker ps -a` 확인 | ☐ |
| D04 | 기존 Dockerfile/compose 검색 | ☐ |
| D05 | Asterisk 컨테이너 빌드 | ☐ |
| D06 | SIP 등록 테스트 (T01) | ☐ |

## 8. 참고 자료
- [[wiki/02_Design/architecture]] — 시스템 아키텍처
- [[wiki/05_Decisions/ADR-001]] — Asterisk 22 LTS 결정