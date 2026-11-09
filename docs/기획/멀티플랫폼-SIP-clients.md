

Asterisk + WebRTC + SIP.js 기반 멀티플랫폼 영상회의 플랫폼 검토
결론: 기존 Flutter + PJSUA2 방식보다 WebRTC + SIP.js 기반 웹 클라이언트를 먼저 개발하는 것을 추천합니다.

특히 목표가 고객사 서버에 설치·납품하는 상용 IP-PBX 및 영상회의 플랫폼이라면, 브라우저 기반으로 시작하는 편이 초기 개발 속도, 플랫폼 호환성, 배포 및 유지보수 측면에서 유리합니다.

단, 100명 규모의 다자간 영상회의까지 고려한다면 SIP.js만으로 모든 문제를 해결할 수는 없습니다.

1. Flutter + PJSUA2 vs WebRTC + SIP.js
비교 항목

Flutter + PJSUA2

WebRTC + SIP.js

Windows

네이티브 앱

브라우저

macOS

네이티브 앱

브라우저

Android

네이티브 앱

모바일 브라우저

iOS

네이티브 앱

Safari 등

SIP 등록

PJSIP

SIP.js

1:1 영상통화

지원

지원

다자간 영상회의

추가 구현

추가 구현

카메라·마이크

네이티브 API

WebRTC API

설치

OS별 앱 설치

URL 접속

자동 업데이트

앱별 배포

웹 서버 배포

푸시·백그라운드 수신

네이티브 통합 가능

브라우저 제약 큼

자체 UI

Flutter

React/Vue 등

SIP 엔진 라이선스

GPL/상용 검토

SIP.js MIT

개발 난이도

높음

초기에는 상대적으로 낮음

SIP.js는 JavaScript/TypeScript 기반 SIP User Agent 라이브러리입니다. 브라우저의 WebRTC 기능과 연계하여 SIP 음성·영상통화를 구현할 수 있습니다.

중요한 차이: SIP.js는 SIP 신호 처리를 담당하고, 실제 영상·음성 송수신은 브라우저의 WebRTC 엔진이 담당합니다.

따라서 PJSUA2를 직접 빌드하거나 Windows DLL, Android NDK, iOS XCFramework를 각각 관리할 필요가 크게 줄어듭니다.

2. 추천하는 최종 아키텍처
Web SIP Client — React + TypeScript + SIP.js

Windows · macOS · Android · iOS · PWA
SIP 전화 UI

영상통화 UI

회의실 UI

HTTPS / SIP over WSS / DTLS-SRTP
고객사 Docker Compose 서버

Nginx / Caddy

HTTPS · WSS 프록시
Management API

계정 · 회의실 · 인증
Asterisk 22 LTS

PJSIP · WebRTC · ConfBridge SFU
STUN / TURN (coturn)

외부망 및 NAT 환경 미디어 연결
SIP / RTP
기존 SIP 영상전화기

동일 PBX 내선 및 회의실 연동
Asterisk 공식 문서에서도 WebRTC 클라이언트 연동을 위해 HTTPS/WSS, PJSIP WebSocket transport, webrtc=yes, DTLS-SRTP 등을 구성하도록 안내합니다.


Asterisk Documentation
 

3. 기존 Asterisk 서버에서 변경할 사항
기존 Docker 기반 SIP 전화기 구성은 유지하고, WebRTC용 설정을 추가합니다.

PJSIP WebRTC Endpoint 예시
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0

[webrtc-endpoint](!)
type=endpoint
context=internal
disallow=all
allow=opus,ulaw,vp8,h264
webrtc=yes
direct_media=no
max_audio_streams=1
max_video_streams=8
이것은 공통 Endpoint 템플릿 예시입니다. 실제 동작하려면 내선별 auth, aor, endpoint 정의와 WSS TLS 서버 설정을 추가해야 합니다.

webrtc=yes는 ICE, DTLS-SRTP, RTCP multiplexing 등 WebRTC 관련 설정을 활성화하는 데 사용됩니다.


Asterisk Documentation
 

영상회의 설정
[video_bridge]
type=bridge
video_mode=sfu
Asterisk 공식 SFU 예제도 브라우저 영상회의에서 다중 영상 스트림을 전달하는 구성을 설명합니다.


Asterisk Documentation
 

다만 다중 영상 렌더링은 별도 검증해야 합니다. SIP.js의 기본 SimpleUser는 단일 세션 중심의 단순 API이므로, 여러 참가자 영상을 관리하는 기능은 전체 SIP.js API와 WebRTC 미디어 처리를 이용해 구현해야 합니다.


GitHub
 

4. 멀티플랫폼 웹 클라이언트 설계
10 Best Video Conferencing Platforms In 2026



Desktop Web

Windows / macOS · Chrome, Edge, Safari

即时通信 IM H5_腾讯云



Mobile Web / PWA

Android / iOS · 반응형 화면

화면 구성 참고 이미지이며 실제 구현 화면은 아닙니다.
초기 UI는 네 가지 화면으로 시작하면 충분합니다.

화면

기능

로그인 / SIP 등록

내선 계정 연결 및 상태 표시

다이얼러

내선번호 입력, 음성·영상 발신

통화 화면

로컬·원격 영상, 음소거, 카메라 전환

회의실

6000번 접속, 참가자 및 영상 표시

향후 관리자가 회의실을 생성하고 초대 링크를 발급하는 기능도 추가할 수 있습니다.

5. 프로젝트 폴더 구조 변경안
asterisk-video-platform/
├── server/
│   ├── asterisk/
│   │   ├── Dockerfile
│   │   └── config/
│   ├── coturn/
│   ├── reverse-proxy/
│   └── compose.yaml
│
├── web-client/
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   ├── features/
│   │   │   ├── login/
│   │   │   ├── dialer/
│   │   │   ├── call/
│   │   │   └── conference/
│   │   ├── sip/
│   │   │   ├── SipClient.ts
│   │   │   ├── SipSession.ts
│   │   │   ├── MediaManager.ts
│   │   │   └── ConferenceManager.ts
│   │   └── pages/
│   ├── public/
│   ├── package.json
│   └── vite.config.ts
│
├── management-api/
├── tests/
│   ├── e2e/
│   ├── sip/
│   └── media/
└── docs/
6. 상용 라이선스 비교
구성요소

라이선스

고객사 납품

Asterisk

GPLv2

GPL 의무 준수

SIP.js

MIT

자체 상용 소스 비공개 가능

React

MIT

상용 사용 가능

TypeScript

Apache 2.0

상용 사용 가능

coturn

BSD 계열

라이선스 고지 준수

자체 웹 클라이언트

자체 라이선스

비공개 배포 가능

SIP.js는 MIT 라이선스이므로 PJSUA2 기반 네이티브 클라이언트에 비해 독점 상용 제품 개발 시 라이선스 관리가 단순합니다.


GitHub
 

물론 Asterisk 자체의 GPL 배포 의무와 H.264 등 코덱 관련 사항은 그대로 남습니다.

7. 단계별 개발 로드맵
단계

목표

핵심 검증

MVP-1

Windows/macOS 브라우저 1:1 영상통화

SIP WSS, WebRTC, H.264/VP8

MVP-2

Android/iOS 브라우저 지원

카메라, 마이크, Safari 호환성

MVP-3

3~4인 영상회의

ConfBridge SFU, 다중 영상

MVP-4

PWA 및 설치형 웹앱

앱 설치, 세션 복구, UI

고도화-1

10~30인 회의

품질, 대역폭, 안정성

고도화-2

100인 회의

전용 SFU 도입 여부 결정

특히 iOS Safari는 브라우저가 백그라운드로 전환되거나 화면이 잠기면 WebRTC 세션이 제한될 수 있으므로, 모바일 앱 수준의 상시 전화 수신은 PWA만으로 보장할 수 없습니다.

8. 최종 기술 선정 제안
추천 기술 기준선

계층

기술

웹 UI

React + TypeScript + Vite

SIP Client

SIP.js

영상/음성

Browser WebRTC

PBX

Asterisk 22 LTS

영상회의

ConfBridge SFU

HTTPS/WSS

Caddy 또는 Nginx

NAT 대응

STUN/TURN

배포

Docker Compose

상용 라이선스

자체 웹앱 + GPL Asterisk 분리



초기에는 WebRTC + SIP.js를 주력 클라이언트로 전환하는 것을 권장합니다.

이 방향은 하나의 웹 코드베이스로 네 운영체제를 지원할 수 있고, 설치 및 업데이트 부담을 줄일 수 있습니다. 특히 고객사 내부망에 서버를 설치하는 형태와 잘 맞습니다.

단, 고객사가 요구하는 것이 단순한 영상회의인지, 스마트폰에서 일반 전화 앱처럼 백그라운드 수신까지 가능한 업무용 전화 시스템인지에 따라 후속 네이티브 앱 필요성은 달라집니다.

다음 개발 단계는 기존 asterisk-video-mvp에 WebRTC/WSS 설정과 React + SIP.js 웹 클라이언트를 추가하고, Docker Compose로 함께 실행되는 통합 MVP를 만드는 것입니다.


https://appletreeda.synology.me:5091/ns/sharing/WCrCg
