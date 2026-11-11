# macOS Client 운영 지식 (재발 방지 노트)

**날짜**: 2026-11-12
**버전**: v1.0

| # | 지식 | 상세 | 출처 |
|---|------|------|------|
| K1 | Docker Desktop(macOS)에서 단말 Contact는 `172.19.0.1`로 보인다 | 정상. 포트포워딩 NAT. ICE 후보는 sip_ua 포크가 `c=` 보정(ADR-005) | verify.sh |
| K2 | 서버 호스트 IP는 `MEDIA_ADDRESS` 한 곳에만 쓰이고 **컨테이너 시작 시 고정** | `.env` 수정 + asterisk·ops 재생성 필요 (`update-server-ip.sh`) | 서버 가이드 |
| K3 | `--check`는 확인만 한다 | rc 0 변경 없음 / 1 감지 실패 / 2 변경 필요 / 3 통화 중 보류 | 서버 가이드 |
| K4 | launchd는 `~/Downloads` 스크립트 실행 불가(TCC, rc=126) | 자동 감시 필요 시 리포를 Downloads 밖으로 | 11-11 |
| K5 | "악성 코드 확인 불가" 경고 = ad-hoc 서명 + quarantine | 빌드 이상 아님. `xattr -d com.apple.quarantine` | 11-12 |
| K6 | DMG `Applications`는 **심볼릭 링크**여야 한다 | `ln -s /Applications <root>/Applications` (폴더 생성 금지) | build_macos.sh |
| K7 | sip_ua `voiceOnly=true`는 영상 **수신까지** 끈다 | 카메라 없음은 recvonly로 협상(ADR-006) | v0.0.17 |
| K8 | 같은 내선 중복 로그인 시 OPS 로그가 한 내선에 섞인다 | session 헤더 host로 구분 가능, 단말별 내선 고정 | 11-12 |
| K9 | 로그 전송 기본 모드 `INFO + 이벤트`는 DEBUG(5초 통계) 미전송 | 상세 분석 시 앱 "로그 전송 설정" → DEBUG | v0.0.13 |
| K10 | 유선/Wi-Fi 대역이 다르면 서버 IP 전환 시 단말이 접근 못 한다 | 단말도 같은 대역(192.168.0.x) 필요 | 11-11 |
| K11 | PRD NAS(nas2=192.168.11.2)는 192.168.0.x에서 미도달 | GitHub만 동기화, git-sync가 SKIP | 11-11 |
