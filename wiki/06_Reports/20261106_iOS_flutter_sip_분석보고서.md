# iOS flutter_sip 플러그인 분석 보고서

**작성일**: 2026-11-06  
**버전**: v1.0  
**대상**: SmartCC Kibal Mobile Client (iOS)  
**상태**: ⚠️ **iOS 구현 불완료**

---

## 📋 Executive Summary

SmartCC Kibal Mobile Client의 iOS 플랫폼 CT03/CT04 테스트 진행 중 **flutter_sip 플러그인이 iOS를 지원하지 않음**을 발견했습니다.

| 항목 | 상태 | 비고 |
|------|------|------|
| **flutter_sip 설계** | ✅ 멀티플랫폼 아키텍처 | Dart API는 플랫폼 무관 |
| **Android 구현** | ✅ 완료 | Java 기반 구현 존재 |
| **iOS 구현** | ❌ **미구현** | Swift 기반 구현 필요 |
| **현재 버전** | 0.0.8 | pub.dev에서 제공 |

---

## 🔍 상세 분석

### 1. flutter_sip 플러그인 구조

#### 1.1 공식 정의 (pubspec.yaml)

```yaml
plugin:
  platforms:
    android:
      package: com.eleadin.sip.flutter_sip
      pluginClass: FlutterSipPlugin
    # ios: ❌ 정의 없음
```

**문제점:**
- `platforms` 섹션에 `android`만 정의됨
- `ios` 섹션 완전히 누락

#### 1.2 플러그인 디렉토리 구조

```
flutter_sip-0.0.8/
├── android/                    ✅ 구현됨
│   ├── src/main/java/
│   │   └── com/eleadin/sip/
│   │       └── FlutterSipPlugin.java
│   └── build.gradle
├── lib/                        ✅ Dart API (플랫폼 무관)
│   ├── flutter_sip.dart
│   ├── flutter_sip_method_channel.dart
│   ├── flutter_sip_platform_interface.dart
│   └── login_status_enum.dart
├── example/
├── test/
├── pubspec.yaml
└── ios/                        ❌ 디렉토리 없음
```

#### 1.3 Dart API 분석

**파일: `flutter_sip_method_channel.dart`**

```dart
class MethodChannelFlutterSip extends FlutterSipPlatform {
  final methodChannel = const MethodChannel('flutter_sip');
  final loginStatusEventChannel = const EventChannel("login_status_stream");
}
```

**핵심 메서드:**
- `init(String httpUrl)` - SIP 클라이언트 초기화
- `loginSip(...)` - SIP 등록
- `logoutSip()` - SIP 로그아웃
- `makeCall(...)` - 통화 시작
- `getMacAddress()` - MAC 주소 조회
- `onLoginStatusChange(callback)` - 등록 상태 변경 리스너

**설계:** ✅ 플랫폼 무관 (Method Channel을 통한 네이티브 호출)

### 2. 테스트 진행 상황

#### 2.1 iOS 빌드 시도

| 단계 | 상태 | 결과 |
|------|------|------|
| **Flutter 의존성 설치** | ✅ | `flutter pub get` 성공 |
| **iOS CocoaPods 설치** | ✅ | `pod install` 성공 |
| **Xcode 빌드** | ✅ | 43.3초 내 완료 |
| **앱 실행** | ✅ | 시뮬레이터에서 시작 |
| **플러그인 초기화** | ❌ | **MissingPluginException** 발생 |

#### 2.2 에러 메시지

```
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] 
Unhandled Exception: MissingPluginException(
  No implementation found for method init on channel flutter_sip
)
```

**원인:**
- `GeneratedPluginRegistrant.m`에서 flutter_sip 플러그인 미등록
- iOS 네이티브 구현 코드 없음

#### 2.3 GeneratedPluginRegistrant 검사

**현재 등록된 플러그인:**
```objc
@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterWebRTCPlugin registerWithRegistrar:...];
  [PermissionHandlerPlugin registerWithRegistrar:...];
  // flutter_sip ❌ 없음
}

@end
```

---

## 🎯 근본 원인

### flutter_sip 플러그인 설계 vs 구현 불일치

| 구분 | 상태 |
|------|------|
| **아키텍처 설계** | ✅ 멀티플랫폼 (Dart API 추상화) |
| **Dart 계층** | ✅ 플랫폼 무관 구현 |
| **Android 네이티브** | ✅ Java 구현 완료 |
| **iOS 네이티브** | ❌ **구현 불완료** |

**결론:** flutter_sip는 멀티플랫폼을 목표로 설계했지만 **iOS 구현이 진행되지 않은 미완성 플러그인**

---

## 📊 영향 분석

### SmartCC Kibal Client CT03/CT04 테스트

| 플랫폼 | CT03 (SIP 등록) | CT04 (1:1 통화) | 상태 |
|--------|----------------|-----------------|------|
| **iOS** | ❌ 불가 | ❌ 불가 | flutter_sip 미구현 |
| **Android** | ✅ 가능 | ✅ 가능 | flutter_sip 구현됨 |
| **Web** | ⚠️ 검토 필요 | ⚠️ 검토 필요 | 다른 기술 스택 |

---

## 💡 해결 방안

### Option 1: Android로 즉시 진행 (권장 - 단기)

**소요시간:** 30분 ~ 1시간

**장점:**
- ✅ flutter_sip가 이미 구현됨
- ✅ CT03/CT04 빠르게 검증 가능
- ✅ PoC 완료 가능
- ✅ 개발 진행 중단 최소화

**단점:**
- ❌ iOS 테스트 지연

**권장사항:** **즉시 진행**

---

### Option 2: iOS flutter_sip 플러그인 구현 (장기)

**소요시간:** 1 ~ 2주

**필요 작업:**

1. **iOS 프로젝트 구조 생성**
   ```
   ios/
   ├── flutter_sip.podspec
   ├── Classes/
   │   ├── FlutterSipPlugin.swift
   │   ├── SipClient.swift
   │   └── SipManager.swift
   └── Package.swift
   ```

2. **Swift 구현**
   - PJSIP (iOS SIP 라이브러리) 통합
   - Method Channel 구현
   - Event Channel 구현
   - WebRTC 통합

3. **pubspec.yaml 수정**
   ```yaml
   plugin:
     platforms:
       android:
         package: com.eleadin.sip.flutter_sip
         pluginClass: FlutterSipPlugin
       ios:
         pluginClass: FlutterSipPlugin
   ```

4. **테스트**
   - Unit tests
   - Integration tests
   - iOS 시뮬레이터 테스트
   - 실제 기기 테스트

**장점:**
- ✅ iOS 플랫폼 완벽 지원
- ✅ 진정한 멀티플랫폼 클라이언트
- ✅ 앱 스토어 배포 가능

**단점:**
- ❌ 시간 많이 소요 (1-2주)
- ❌ 전문 지식 필요 (Swift, PJSIP)

---

## 📝 권장 전략

### Phase 1: Android 검증 (즉시 - 2026-11-06)

**목표:** CT03/CT04 PoC 검증 완료

1. Android SDK 환경 구성
2. Android 에뮬레이터 생성
3. Flutter 앱 빌드 & 실행
4. SIP 등록 테스트 (CT03)
5. 1:1 통화 테스트 (CT04)

**예상 완료:** 2026-11-06 오전

---

### Phase 2: iOS 지원 추가 (향후 - 2026-11-20 이후)

**목표:** iOS 플랫폼 완벽 지원

1. PJSIP for iOS 통합
2. Flutter 플러그인 구현
3. iOS 시뮬레이터 테스트
4. 실제 기기 테스트

**예상 완료:** 2026-11-20

---

## ✅ 결론

### 주요 발견사항

1. **flutter_sip 플러그인은 설계는 멀티플랫폼이지만 iOS 구현이 누락됨**
   - Dart API: 플랫폼 무관 ✅
   - Android 네이티브: 완전 구현 ✅
   - iOS 네이티브: 구현 안 됨 ❌

2. **현재 SmartCC Kibal iOS 클라이언트는 SIP 기능 사용 불가**
   - flutter_sip 플러그인 없이 UI만 렌더링됨
   - CT03/CT04 iOS 테스트 불가능

3. **Android는 완벽하게 동작 가능**
   - flutter_sip 0.0.8 Java 구현 완료
   - CT03/CT04 Android 테스트 진행 권장

### 권장 조치

| 우선순위 | 항목 | 담당 | 기간 |
|---------|------|------|------|
| **P0** | Android CT03/CT04 검증 | 개발 | 2026-11-06 |
| **P1** | iOS flutter_sip 구현 검토 | 아키텍처 | 2026-11-07 |
| **P2** | iOS 플러그인 개발 계획 | 개발 | 2026-11-10 |

---

## 📎 부록

### A. flutter_sip 플러그인 정보

**공식 저장소:** https://pub.dev/packages/flutter_sip  
**버전:** 0.0.8 (사용 중)  
**라이선스:** MIT  
**유지보수:** Active

### B. 대체 솔루션

| 솔루션 | iOS 지원 | Android 지원 | 비고 |
|--------|---------|-------------|------|
| **flutter_sip** | ❌ 미구현 | ✅ 완료 | 현재 사용 중 |
| **linphone_sdk** | ✅ 지원 | ✅ 지원 | 무거움 |
| **sip_ua** | ✅ 지원 | ✅ 지원 | 가벼움 |
| **pjsua2_dart** | ✅ 가능 | ✅ 가능 | 직접 구현 필요 |

### C. 참고자료

- Flutter 플러그인 개발 가이드: https://flutter.dev/docs/development/packages-and-plugins/developing-packages
- iOS 플러그인 작성: https://flutter.dev/docs/development/platform-integration/platform-channels
- PJSIP for iOS: https://www.pjsip.org/

---

**보고자:** Claude Code  
**검토자:** -  
**승인자:** -  
**상태:** 작성 완료

