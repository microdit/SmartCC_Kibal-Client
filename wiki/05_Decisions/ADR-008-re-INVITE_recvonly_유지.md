# ADR-008: re-INVITE 수락에도 ADR-006 수신 전용 옵션을 유지한다

**날짜**: 2026-11-12
**상태**: 수용(Accepted) — D1 구현·analyze/test·v0.0.23 릴리스 완료(TC-D1 실기 검증 대기)
**관련**: [[wiki/05_Decisions/ADR-006-카메라없는단말_영상수신전용]], ADR-004(sip_ua 엔진), ADR-005(sip_ua 포크)
**상위**: [[docs/보고서/20261112_통화품질_원인규명_작업계획서_v1.0]] §4-D

---

## 배경

ADR-006은 "카메라 없는 단말은 `recvonly`로 영상을 수신한다"를 결정했고, 현재 코드는 두 경로에만 적용되어 있다.

| 경로 | 위치 | 적용 |
|------|------|------|
| 발신 | `sip_client.dart:307` `customOptions: voiceOnly ? _receiveVideoOptions() : null` | ✅ |
| 착신 | `sip_client.dart:354-357` `MapHelper.merge(answerOptions, _receiveVideoOptions())` | ✅ |
| **재협상** | `sip_client.dart:616-638` `onNewReinvite` → `_acceptReinvite` → `accept(<String, dynamic>{})` | ❌ |

ConfBridge는 참가자 입·퇴장마다 re-INVITE를 보낸다(로그 `01:10:35`, `01:48:13`). 따라서 초기 협상에서 `recvonly`를 얻어도 **재협상 응답이 기본 옵션으로 되돌아가면 수신 전용 상태가 깨질 위험**이 있다.

추가 관찰: `_acceptReinvite`는 수락 500ms 후 `_logTransceivers()`(`:633-634`, `:657-679`)를 호출하지만, 제공 로그에는 `SIP transceivers` INFO 라인이 없다. 재협상 후 실제 direction을 검증할 로그 기준선이 없는 상태다.

---

## 결정

1. `_acceptReinvite`가 `accept()`에 전달하는 옵션에 **`_receiveVideoOptions()`를 병합**한다.
   - 카메라 없는 단말: `recvonly` 유지
   - 카메라 있는 단말: `sendrecv` 유지(기존 동작 보존)
   - 사용자가 명시적으로 "음성 통화"를 선택한 경우에만 수신까지 끈다(ADR-006 원칙 계승)
2. 재협상 수락 직후 `SIP transceivers` 로그가 **반드시 1회 남도록** 보장하고, `mid:kind:direction/currentDirection`에 video 방향을 기록한다.
3. 옵션 병합은 `MapHelper.merge`로 기존 answer 옵션을 보존하며 덮어쓰지 않는다.

---

## 대안

| 대안 | 기각 이유 |
|------|-----------|
| sip_ua 포크에서 전역 기본값으로 설정 | 발신/착신/재협상 경로가 달라 부작용 범위가 큼 |
| re-INVITE 무시 | H5(15~17초 ICE 실패) 회귀. 자동 수락은 유지해야 함 |
| UI에서 사용자가 매번 재설정 | 재협상은 자동 발생하므로 실사용 불가 |

---

## 결과

- **장점**: 참가자 입·퇴장이 반복되는 6000 회의에서 카메라 없는 1101의 영상 수신이 유지됨.
- **단점**: 재협상마다 옵션 병합 1회 추가(무시 가능한 비용).
- **검증**: TC-D1 — 1101로 6000 입장 → 3자 재협상 유도 → `SIP transceivers`에 video `recvonly` 유지, `videoKB>0`, `decodedFrames>0`.
- **영향 파일**: `macos-client/lib/src/sip/sip_client.dart` (1개), 테스트 1건 추가.

---

## 후속

- D2(원격 스트림 누적 정리)와 함께 v0.0.23+로 묶어 릴리스한다.
- 검증 완료 후 이 ADR 상태를 `Accepted`로 변경하고 ADR-006의 "제안" 상태도 함께 갱신한다.

## 구현 (2026-11-13 00:10, v0.0.23)

| 파일 | 변경 |
|------|------|
| `macos-client/lib/src/sip/sip_client.dart` | `_receiveOnlyVideo` 필드 추가. `call()`은 `voiceOnly`, `accept()`은 `recvOnlyVideo` 값을 저장 |
| 동일 파일 `_acceptReinvite` | `accept(<String, dynamic>{})` → `MapHelper.merge(options, _receiveVideoOptions())` 후 `accept(options)`. 응답 로그에 `recvOnlyVideo=...` 추가 |
| `macos-client/lib/src/media/media_manager.dart` (D2) | `retainRemoteVideoTracks`에서 video 트랙이 모두 inactive인 스트림만 `_remoteSessions`에서 제거. **오디오 전용 스트림은 보존**(기존 회의 음성 유실 회귀 방지) |

### 검증

- `flutter analyze` **No issues**, `flutter test` **17/17 통과**
- `./scripts/release_macos.sh --skip-tests` → **v0.0.23 (build 23)** DMG, sha256 `ace1cf4f8c34e7fee1ebe8bac6ba951f395003f79cde56a05dee4ce27d48eaeb`(`--no-bump --install` 재빌드 설치본; 최초 빌드는 `21d0994…`), x86_64+arm64, adhoc 서명
- D3 기준선: 제공된 1102 로그는 `SIP accept video=`(v0.0.17 추가)가 없어 **v0.0.16 이하** 빌드. `1102.meta.json`의 `v0.0.19`는 마지막 세션 기준이라 로그 기준선으로 부적합

### 잔여

- **TC-D1 실기**: 1101(카메라 없음)으로 6000 3자 회의 → 참가자 입·퇴장 re-INVITE 후 `SIP transceivers`에 video `recvonly` 유지, `videoKB>0`, `decodedFrames>0` 확인
- 실기 통과 시 [[wiki/05_Decisions/ADR-006-카메라없는단말_영상수신전용]]도 `Accepted`로 변경

## 변경 이력

| 버전 | 날짜 | 변경 | 작성자 |
|------|------|------|--------|
| v1.0 | 2026-11-12 | re-INVITE 수락 시 ADR-006 옵션 누락 발견·병합 결정 | opencode |
| v1.1 | 2026-11-13 | D1/D2 구현·v0.0.23 릴리스, **Accepted**로 변경 | opencode |
