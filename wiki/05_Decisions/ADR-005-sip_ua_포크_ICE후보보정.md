# ADR-005: sip_ua 로컬 포크로 원격 SDP ICE 후보 보정

| 항목 | 값 |
|------|---|
| **결정 일자** | 2026-11-11 |
| **결정자** | Kibal Team |
| **상태** | 결정됨 (Accepted, 임시 우회) |
| **버전** | v1.0 |
| **적용 대상** | `macos-client` (이후 iOS/Windows/Android 이식 시 동일 검토) |
| **관련** | [[wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0]], [[wiki/05_Decisions/ADR-004]] |

## 1. 배경

DEV Asterisk는 Docker 컨테이너(`172.19.0.2`)에서 실행되며, 호스트 LAN IP(`192.168.11.39`)로 RTP 포트가 1:1 매핑된다.

Asterisk answer SDP는 다음과 같다.

```
c=IN IP4 192.168.11.39
m=audio 10048 UDP/TLS/RTP/SAVPF ...
a=candidate:Hac130002 1 UDP 2130706431 172.19.0.2 10048 typ host
```

- `media_address=192.168.11.39`는 `c=`만 보정한다.
- `external_media_address`도 ICE 후보 주소를 보정하지 못한다.
- macOS Docker Desktop에서는 컨테이너에 LAN IP를 부여할 수 없고, `--network host`도 VM IP(`192.168.65.4`)라 클라이언트가 도달할 수 없다.
- `ice_support=no`로 끄면 클라이언트가 `488 Bad Media Description`으로 거부한다.

미디어는 peer-reflexive 쌍으로 양방향 정상이었지만, 클라이언트 libwebrtc는 시그널링된 `172.19.0.2`로의 connectivity check/consent가 실패하자 `RTCIceConnectionStateFailed`로 전환했고, `sip_ua`가 즉시 BYE(`408 ICE Connection Failed`)를 보냈다.

## 2. 결정

- `sip_ua 1.1.0`을 **`macos-client/packages/sip_ua`로 로컬 포크**하고 `dependency_overrides`로 참조한다.
- 원격 SDP의 ICE 후보 중 **Docker 브리지 대역(172.16.0.0/12)** 주소를, 해당 미디어의 `c=` 주소가 도달 가능한 주소일 때 `c=`로 치환한다.
- 적용 지점:
  - 원격 offer: `_sdpOfferToWebRTC()` 반환 직전
  - 원격 answer: 모든 `setRemoteDescription` 직전
- 함수: `_rewriteUnreachableIceCandidates()`, `_isDockerBridgeAddress()`
- 조건:
  - `c=`가 `0.0.0.0`이 아니고 172.16/12가 아닐 때만 치환
  - 후보 IP가 172.16/12일 때만 치환 (LAN/공인 후보는 보존)

## 3. 근거

| 대안 | 검토 결과 |
|------|-----------|
| **sip_ua 로컬 포크 (채택)** | 클라이언트 단독 수정, 서버/인프라 변경 없음, 오디오 단독 118초 유지 확인 |
| TURN 서버 | 호스트에서 컨테이너 `172.19.0.2`로 직접 도달 불가, coturn을 Docker 네트워크에 두면 relay 주소/포트 매핑 복잡 |
| Asterisk 네이티브 실행 | DEV 인프라/운영 콘솔 전면 변경 필요 |
| Docker host 네트워크 | macOS Docker Desktop은 VM IP만 노출 (`192.168.65.4`) |
| `ice_support=no` | 클라이언트 488 거부 |
| 서버 SDP 후보 직접 조작 | `res_pjsip`에 해당 옵션 없음 |

## 4. 결과 및 영향

- **긍정**: 오디오 단독 통화가 118초간 유지되어 원래 원격 오디오 버그가 해소됨. 서버/인프라 변경 없이 Docker NAT 환경에서 동작.
- **부정/리스크**:
  - `sip_ua` 업스트림 업데이트 시 포크 병합 필요 (유지보수 부담)
  - `c=`가 172.16/12인 경우(예: `media_address` 미설정)에는 치환하지 않아 효과 없음
  - 후보 보정만으로는 **재협상 실패를 해결하지 못했다** — 실제 원인은 앱의 re-INVITE 미응답(H5, 아래 6절)
- **보안**: `dtls_verify=fingerprint`는 DEV 한정. PRD는 인증서/CA 정책 재검토 필요.

## 5. 2026-11-11 13:00 추가: H5 규명과 포크 보완

- v1.4 로그/서버 SDP 분석 결과, 후보 보정은 **정상 적용**되고 있었다(오디오/영상 모두 `c=192.168.11.39`로 치환).
- 영상/다자간 실패의 직접 원인은 re-INVITE에 앱이 **200 OK를 보내지 않은 것**(`onNewReinvite` 빈 구현)이었다.
- 상세는 [[wiki/06_Reports/20261111_원격오디오_ICE문제_개발보고서_v1.0]]의 H5 참조.
- 포크 추가 보완: `_processInDialogSdpOffer`의 `upgradeToVideo`가 re-INVITE마다 새 video track을 추가하던 문제를 수정. 이미 로컬 video track/sender가 있으면 skip.
- 후보 보정 포크는 계속 유지한다(오디오 단독 118초 유지의 근거).

## 6. 후속 조치

1. v0.0.8 실기 재검증(영상/3자 5분 이상)으로 후보 보정 + H5 수정의 결합 효과 확인
2. re-INVITE 응답 후 서버가 영상 RTP를 실제 송신하는지 확인(`Sent RTP type 100`); 0건이면 ConfBridge SFU 설정 재점검
3. 서버가 도달 가능한 후보를 광고할 수 있게 되면(예: Linux bridged VM, 네이티브 Asterisk, TURN) 포크 제거 검토
4. 장기적으로 `sip_ua` 업스트림에 SDP 후보 보정 훅 또는 ICE 실패 복원력 패치 제안


## 추가 변경 (2026-11-12, ADR-007)
- `rtc_session.dart` `localSdpTransformer` 전역 훅: `_createLocalDescription`에서 offer/answer(재협상 포함) SDP 변환
- `sip_ua.dart` export: `MapHelper`, `RTCSession`, `localSdpTransformer`
