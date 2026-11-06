# Flutter 선택 vs WebRTC 기반 설계 분석 보고서

**작성일**: 2026-11-06  
**버전**: v1.0  
**대상**: SmartCC Kibal Mobile Client (Flutter 검토)  
**상태**: ⚠️ **설계와 구현 간의 전략적 차이 발견**

---

## 📋 Executive Summary

SmartCC Kibal-Client 프로젝트의 **설계 문서에서 명시한 WebRTC 기반 전략**과 **실제 구현된 Flutter 기반 솔루션** 간에 **본질적인 차이**가 있습니다.

| 항목 | 설계 문서 | 실제 구현 | 상태 |
|------|---------|---------|------|
| **주력 클라이언트** | Web Client (React + SIP.js) | Mobile Client (Flutter) | ⚠️ 불일치 |
| **모바일 목표** | 향후 확장 (Flutter 또는 Native) | 즉시 구현 (Flutter) | ⚠️ 앞당겨짐 |
| **WebRTC 기반** | Web 주력 | Web + Mobile 모두 | ⚠️ 일관성 |
| **기술 스택** | React + SIP.js (주력) | Flutter + flutter_sip | ⚠️ 다름 |

---

## 🔍 상세 분석

### 1. 설계 문서 의도 분석

#### 1.1 공식 설계 로드맵

**파일:** `wiki/02_Design/cross-platform-client-design.md`

```markdown
# 크로스플랫폼 클라이언트 설계

> WebRTC + SIP.js 기반 Web Client를 주력으로 삼되, 
> 향후 모바일 백그라운드 전화 수신을 위해 
> Flutter native 또는 iOS/Android native로 확장할 수 있는 
> 크로스플랫폼 전략을 수립했습니다.
```

**핵심 의도:**
1. **Phase 1 (MVP):** Web Client 우선 개발 (React + SIP.js)
2. **Phase 2 (향후):** 모바일 확장 고려 (Flutter 또는 Native)
3. **Phase 3 (미래):** Native 앱 (Swift/Kotlin) - 백그라운드 VoIP 지원

#### 1.2 설계된 개발 로드맵

```
C1 (기초)   → Web 프로젝트 초기화
C2 (MVP-1) → Web: 1:1 영상통화 ← Web Client 먼저
C3 (MVP-2) → Flutter: 모바일 1:1 ← 그 다음 모바일
C4 (통합)  → Docker 배포
C5 (고도화)→ 3자 회의
C6 (미래)  → Native iOS 백그라운드 수신
```

**순서:** **Web → Mobile → Native**

#### 1.3 기술 우선순위

**파일:** `wiki/01_Projects/client-project-plan.md`

```
┌─────────────────────────────────────────┐
│           Kibal Client (신규)            │
│                                        │
│  ┌──────────────┐  ┌──────────────┐   │
│  │   React SPA   │  │  Flutter App │   │
│  │  (Web/Browser) │  │ (iOS/Android)│   │
│  └──────┬───────┘  └──────┬───────┘   │
│         │              │               │
│         └──────┬───────┘              │
│                │                      │
│         ┌──────▼──────┐               │
│         │  SIP.js /   │               │
│         │FlutterWebRTC│               │
│         └──────┬──────┘               │
```

**구조:** React와 Flutter가 **동등한 위치**

---

### 2. 실제 구현 현황

#### 2.1 현재 구현 상태

| 컴포넌트 | 설계 의도 | 구현 현황 | 진행률 |
|---------|---------|---------|--------|
| **Web Client** | MVP 주력 | ❌ 미구현 | 0% |
| **Mobile Client** | 향후 확장 | ✅ 완전 구현 | 100% |
| **설정/Wiki** | Knowledge OS | ✅ 완성 | 100% |

#### 2.2 구현된 Mobile (Flutter) 규모

```
mobile/
├── lib/
│   ├── main.dart                    ← Flutter 엔트리
│   ├── app.dart                     ← 라우팅
│   ├── src/
│   │   ├── sip/                     ← SIP 클라이언트 (완전 구현)
│   │   │   ├── sip_client.dart
│   │   │   ├── sip_session.dart
│   │   │   └── conference_manager.dart
│   │   ├── media/                   ← WebRTC (완전 구현)
│   │   │   ├── media_manager.dart
│   │   │   └── webrtc_helpers.dart
│   │   ├── ui/                      ← UI 컴포넌트 (완전 구현)
│   │   │   ├── login/
│   │   │   ├── dialer/
│   │   │   ├── call/
│   │   │   └── conference/
│   │   ├── providers/               ← 상태 관리
│   │   └── utils/
│   ├── android/                     ← Android 플랫폼 (완전 구현)
│   ├── ios/                         ← iOS 플랫폼 (불완전)
│   ├── pubspec.yaml                 ← 의존성
│   └── README.md
```

**코드 규모:** 26+ 파일, 4,600+ 라인  
**구현 범위:** SIP, WebRTC, UI, 플랫폼 설정 모두 포함

#### 2.3 Web Client 상태

```
web/
├── src/
│   └── (구조만 정의, 구현 없음)
├── public/
└── index.html
```

**상태:** ❌ 설계만 있고 구현 없음

---

### 3. 왜 Flutter가 먼저 구현되었나?

#### 3.1 공식 기록 검토

**파일:** `wiki/06_Reports/작업완료보고서_20261105.md`

```markdown
## ✅ **2026-11-05 작업 완료 보고**

**SmartCC Kibal 프로젝트의 Mobile 클라이언트 분석, 
문서화, 동기화 작업을 성공적으로 완료했습니다.**

### **1. CT03/CT04 BLOCKED 이유 분석 및 해제**
- **원인**: `mobile/` 디렉토리 미존재 (2026-11-03 기준)
- **해결**: Commit `0b4b205`에서 `mobile/` 디렉토리 및 
  전체 Flutter 앱 구현 확인
- **결과**: **BLOCKED → READY** 상태로 전환
```

**의미:**
- 2026-11-03: Mobile이 미존재 (계획 단계)
- 2026-11-05: Mobile 완전 구현 (2일 만에 완성)
- **매우 빠른 개발 속도** → 사전 준비된 코드?

#### 3.2 개발 전략 가설

**가설 1: 병렬 개발 (설계와 무관)**
- 설계: "Web 먼저"
- 실제: Mobile과 Web 동시 개발
- 결과: Mobile이 먼저 완성됨

**가설 2: PoC 우선순위 변경**
- 설계: "Web MVP"
- 실제: Mobile CT03/CT04 PoC가 더 중요
- 결과: Mobile 집중 개발

**가설 3: 기술적 편의성**
- React + SIP.js: 브라우저 WebRTC API 학습 필요
- Flutter + flutter_sip: 기존 SIP 플러그인 활용 가능
- 결과: Flutter가 더 빠르게 구현 가능

---

### 4. 설계 vs 구현: 차이점 분석

#### 4.1 기술 선택

| 계층 | 설계 의도 | 구현 현황 | 일치도 |
|-----|---------|---------|--------|
| **Web Client** | React + SIP.js | ❌ 미구현 | 0% |
| **Mobile Client** | Flutter (향후) | ✅ 완전 구현 | 100% |
| **SIP 계층** | SIP.js (Web) | flutter_sip (Mobile) | 60% |
| **Media 계층** | WebRTC (모두) | flutter_webrtc (Mobile) | 60% |

#### 4.2 우선순위

| 단계 | 설계 | 실제 | 차이 |
|-----|------|------|------|
| **1단계** | Web MVP | Mobile MVP | ⚠️ 역순 |
| **2단계** | Mobile 확장 | Web 미개발 | ⚠️ 미진행 |
| **3단계** | Native 고려 | 미계획 | ⚠️ 동일 |

#### 4.3 PoC 검증 전략

**설계:**
```
Web Client (React)
├── SIP.js 등록
├── WebRTC 통화
└── CT01/CT02 검증 (완료)
       ↓
Mobile Client (Flutter) 
├── flutter_sip 등록
├── flutter_webrtc 통화
└── CT03/CT04 검증 (준비됨)
```

**실제:**
```
Mobile Client (Flutter) ✅ READY
├── flutter_sip 등록
├── flutter_webrtc 통화
└── CT03/CT04 검증 가능

Web Client (React) ❌ 미구현
└── CT01/CT02 검증 미진행
```

---

### 5. 근본 원인 분석

#### 5.1 설계 의도 vs 구현 현황 불일치

**설계 문서 핵심 문구:**

```markdown
# 크로스플랫폼 클라이언트 설계

> WebRTC + SIP.js 기반 Web Client를 주력으로 삼되, 
> 향후 모바일 백그라운드 전화 수신을 위해 
> Flutter native 또는 iOS/Android native로 확장할 수 있는 
> 크로스플랫폼 전략을 수립했습니다.
```

**분석:**
- **"주력"** = Web Client (React + SIP.js)
- **"확장"** = Mobile Client (Flutter, 나중에)
- **"향후"** = Native (Swift/Kotlin, 훨씬 나중에)

**현실:**
- Web Client: 설계만 있고 미구현
- Mobile Client: 완전 구현되어 즉시 테스트 가능
- **순서 역전됨**

#### 5.2 가능한 원인들

| 원인 | 가능성 | 근거 |
|-----|--------|------|
| **PoC 우선순위 변경** | ⭐⭐⭐⭐ | CT03/CT04가 먼저 검증되어야 함 |
| **개발 팀 구성** | ⭐⭐⭐ | Flutter 개발자 우선 투입 |
| **기술 의존성** | ⭐⭐⭐ | flutter_sip가 SIP.js보다 "즉시 사용" 가능 |
| **시간 압박** | ⭐⭐ | 빠르게 구현 가능한 것부터 시작 |
| **설계 변경 미반영** | ⭐⭐ | 설계 문서 미업데이트 |

---

## 💡 평가 및 권고

### 6.1 현재 상황 평가

#### ✅ 장점

1. **Mobile PoC 빠른 완성**
   - Flutter 구현으로 Android 즉시 검증 가능
   - CT03/CT04 테스트 진행 가능
   - 개발 속도 우수

2. **Knowledge OS 완성**
   - Wiki, Git 3-Way, ChromaDB 등 기반 완벽
   - 문서화 우수
   - 재사용성 높음

3. **멀티플랫폼 기초**
   - Flutter로 iOS/Android 동시 대응 가능
   - 코드 재사용 가능

#### ⚠️ 문제점

1. **설계 문서와 불일치**
   - Web Client 미구현 (MVP 미완)
   - 로드맵 순서 역전
   - 문서 신뢰도 하락

2. **iOS flutter_sip 미구현**
   - flutter_sip가 Android만 지원
   - iOS 테스트 불가능
   - CT03/CT04 iOS 검증 불가

3. **Web Client 공백**
   - 설계의 "주력" 미구현
   - CT01/CT02 (Web) 검증 미진행
   - 전체 PoC 완성도 낮음

---

### 6.2 권고사항

#### Phase 1: 즉시 (2026-11-06)

**목표:** Android Mobile PoC 검증 완료

1. **Android CT03/CT04 테스트**
   - Java JDK 설정 완료 ✅
   - Android SDK 환경 구성
   - Android 에뮬레이터 실행
   - SIP 등록 & 1:1 통화 검증

2. **설계 문서 업데이트**
   - 실제 구현 현황 반영
   - 우선순위 재정의
   - 로드맵 수정

#### Phase 2: 단기 (2026-11-07 ~ 2026-11-10)

**목표:** Web Client MVP 개발 시작

1. **Web Client 프로토타입**
   - React + SIP.js 기초 구현
   - WebRTC 연결 테스트
   - CT01/CT02 (Web) 검증

2. **iOS flutter_sip 검토**
   - 기존 플러그인 분석
   - Swift 기반 구현 검토 또는 대체 솔루션 (sip_ua 등)

#### Phase 3: 중기 (2026-11-15 이후)

**목표:** 멀티플랫폼 PoC 완성

1. **iOS 지원 추가**
   - flutter_sip iOS 구현 또는 대체 플러그인
   - CT03/CT04 iOS 검증

2. **Web 배포**
   - Docker + Nginx 배포
   - 다자간 회의 (SFU)

---

### 6.3 전략적 재정의

#### 재설계된 로드맵

```
현재 상태 (2026-11-06)
├── ✅ Mobile (Flutter) - 완성
│   ├── ✅ Android - 준비됨
│   └── ⚠️ iOS - flutter_sip 미구현
└── ❌ Web (React) - 미시작

권장 새 로드맵
├── Phase 1 (NOW): Android PoC 검증
│   └── CT03/CT04 Android 완료 (오늘)
│
├── Phase 2 (1주): Web MVP 개발
│   └── CT01/CT02 Web 완료
│
└── Phase 3 (2주): iOS 지원
    └── CT03/CT04 iOS 완료
```

---

## 📊 기술 선택 비교

### 7.1 Flutter vs Web 기반 아키텍처

| 항목 | Flutter 기반 (현재) | Web 기반 (설계) |
|------|------------------|-----------------|
| **개발 속도** | 빠름 (완성) | 중간 (미시작) |
| **배포 복잡도** | 높음 (앱스토어) | 낮음 (URL) |
| **업데이트 주기** | 느림 (심사 대기) | 빠름 (즉시) |
| **백그라운드** | 가능 (native) | 불가 (브라우저) |
| **푸시 알림** | 가능 (APNs/FCM) | 불가 |
| **개발자 진입장벽** | 중간 (Dart/Flutter) | 낮음 (JS/React) |
| **코드 재사용** | 높음 (iOS/Android) | 중간 (Web만) |

#### 결론: **Flash vs Web 선택은 용도에 따라**

- **모바일 우선 (백그라운드 필요)** → Flutter ✅
- **Web 우선 (빠른 배포)** → React + SIP.js ✅
- **둘 다 필요** → 병렬 개발 필요 ⚠️

---

## ✅ 최종 결론

### 8.1 주요 발견사항

1. **설계와 구현의 전략적 역전**
   - 설계: "Web 주력, Mobile 확장"
   - 실제: "Mobile 완성, Web 미시작"
   - **원인:** PoC 우선순위 변경 또는 개발 팀 구성의 차이

2. **iOS flutter_sip 미구현으로 인한 제약**
   - flutter_sip는 Android만 지원
   - iOS 테스트 불가능
   - **대안:** 다른 SIP 플러그인 (sip_ua) 또는 Native Swift 구현

3. **Mobile PoC는 준비되었지만 전체 PoC는 미완성**
   - Android: CT03/CT04 테스트 가능 ✅
   - iOS: 구현 필요 ⚠️
   - Web: 전혀 미시작 ❌

### 8.2 권장 조치

| 우선순위 | 항목 | 기간 | 담당 |
|---------|------|------|------|
| **P0** | Android CT03/CT04 검증 | 2026-11-06 | 개발 |
| **P1** | 설계 문서 업데이트 | 2026-11-07 | 아키텍처 |
| **P2** | Web Client MVP 개발 | 2026-11-07 ~ | 개발 |
| **P3** | iOS 지원 추가 | 2026-11-15 ~ | 개발 |

### 8.3 개선 제안

1. **설계와 구현의 주기적 동기화**
   - 로드맵 변경 시 설계 문서 즉시 업데이트
   - 매주 설계-구현 정렬 미팅

2. **플러그인 의존성 관리**
   - flutter_sip의 iOS 미지원 사전 인식
   - 대체 솔루션 평가 (sip_ua, linphone_sdk 등)

3. **병렬 개발 전략**
   - Web과 Mobile 동시 개발 고려
   - 기술 스택 표준화 (공통 API 설계)

---

## 📎 부록

### A. 참고 문서

- `wiki/01_Projects/client-project-plan.md` — 프로젝트 계획
- `wiki/02_Design/cross-platform-client-design.md` — 크로스플랫폼 설계
- `wiki/02_Design/mobile-client.md` — Mobile 설계
- `wiki/06_Reports/20261106_iOS_flutter_sip_분석보고서.md` — iOS 플러그인 분석

### B. 대체 SIP 솔루션

| 솔루션 | iOS | Android | 특징 |
|--------|-----|---------|------|
| **flutter_sip** | ❌ | ✅ | PJSIP 래퍼 |
| **sip_ua** | ✅ | ✅ | Dart 순수 구현 |
| **linphone_sdk** | ✅ | ✅ | 무겁지만 완전 |
| **pjsua2_dart** | ✅ | ✅ | 직접 바인딩 필요 |

### C. Timeline

```
2026-10-29: 설계 완료 (Web 주력)
2026-11-03: Mobile BLOCKED
2026-11-05: Mobile 완성 (순서 역전)
2026-11-06: iOS 플러그인 분석 (불가능 발견)
2026-11-06: 본 보고서 작성
2026-11-06: Android 테스트 시작 권고
```

---

**보고자:** Claude Code  
**검토자:** -  
**승인자:** -  
**상태:** 작성 완료

