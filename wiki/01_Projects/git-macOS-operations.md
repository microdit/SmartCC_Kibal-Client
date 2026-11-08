# macOS Client Git 작업 절차

| 항목 | 내용 |
|------|------|
| **문서 ID** | GIT-MACOS-20261108-001 |
| **프로젝트** | SmartCC_Kibal-Client (멀티플랫폼 SIP 클라이언트) |
| **작성일** | 2026-11-08 |
| **버전** | v1.0 |
| **상태** | 진행 중 |
| **관련** | [[wiki/01_Projects/client-development-tasks-macOS]], [[wiki/06_Reports/macOS-client-개발작업계획서]] |

---

## 1. 브랜치 생성

```bash
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client

# 1. develop에서 최신화
git checkout develop
git pull origin develop

# 2. 새 브랜치 생성 (macOS 네이티브 클라이언트 개발용)
git checkout -b feature/macOS-version

# 3. 생성된 브랜치 확인
git branch --show-current
# 예상 출력: feature/macOS-version
```

---

## 2. 작업 파일 생성/수정

```bash
# 작업 디렉토리 확인
ls -la
# 예상 출력: mobile/  web/  wiki/  docs/  scripts/  ...

# macOS/Windows 클라이언트 관련 파일 생성
# - wiki/02_Design/macOS-client-design.md (v2.0) — 이미 생성됨
# - wiki/02_Design/macOS-client-ui.md — 이미 생성됨
# - wiki/02_Design/macOS-client-roadmap.md — 이미 생성됨
# - wiki/01_Projects/client-development-tasks-macOS.md — 이미 생성됨
# - wiki/06_Reports/macOS-client-개발작업계획서.md — 이미 생성됨
# - wiki/06_Reports/macOS-client-개발보고서.md — 이미 생성됨
```

---

## 3. 커밋

```bash
# 1. 변경 사항 확인
git status --short

# 2. 모든 변경 사항 스테이징
git add -A

# 3. 커밋 메시지 생성
git commit -m "
feat: macOS/Windows 네이티브 클라이언트 개발 준비

- wiki/02_Design/macOS-client-design.md (v2.0): Flutter 기반 macOS 설계
- wiki/02_Design/macOS-client-ui.md: UI 설계서
- wiki/02_Design/macOS-client-roadmap.md: 개발 로드맵
- wiki/01_Projects/client-development-tasks-macOS.md: 작업 분해표
- wiki/06_Reports/macOS-client-개발작업계획서.md: 개발 계획서
- wiki/06_Reports/macOS-client-개발보고서.md: 개발 보고서

관련: [[wiki/02_Design/macOS-client-design]], [[wiki/02_Design/macOS-client-ui]], [[wiki/02_Design/macOS-client-roadmap]]
"

# 4. 커밋 확인
git log --oneline -3
```

---

## 4. 원격 푸시

```bash
# feature/macOS-version 브랜치로 푸시
git push -u origin feature/macOS-version

# GitHub에서 확인
# - https://github.com/microdit/SmartCC_Kibal-Client/tree/feature/macOS-version
```

---

## 5. 3-Way 동기화

```bash
# git-sync.sh 스크립트 사용 (자동 커밋 + dev/prd 푸시)
./scripts/git-sync.sh --auto --no-deploy

# 또는 수동 동기화
git push origin feature/macOS-version
git push dev feature/macOS-version
git push prd feature/macOS-version

# PRD 배포 (별도 설정 필요)
# ./scripts/git-sync.sh --auto --deploy
```

---

## 6. 개발 진행 확인

```bash
# 1. 브랜치 확인
git branch --show-current

# 2. 최신 상태 확인
git log --oneline -3

# 3. 원격 동기화 확인
git status
```

---

## 7. 주간 점검 checklist

| 점검 항목 | 완료 기준 |
|-----------|-----------|
| **브랜치 동기화** | `git pull origin develop` 성공 |
| **문서 갱신** | 작업계획서, 설계서, 로드맵 최신 상태 |
| **코드 변경** | `macos-client/`, `windows-client/` 디렉토리 존재 |
| **CI/CD** | GitHub Action에서 `flutter build macos` 성공 |
| **테스트** | CT01(CT02, CT03, CT05) 결과 리포트 업데이트 |

---

## 8. 문서 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-11-08 | TVS (Mistral Vibe) | 최초 작성 |
