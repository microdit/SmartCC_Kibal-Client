[AI Agent 작업 지시서] macOS용 NAS(nas2) SSH 및 SMB 연동 환경 구성 (v1.1)

192.168.0.x` 192.168.11.x` 대역 연결

# Role & Objective
너는 macOS 시스템 및 네트워크 엔지니어링에 특화된 AI 에이전트다.
현재 사용자의 **macOS** 환경에서 다른 서브넷(`192.168.11.x`)에 위치한 NAS(`192.168.11.2`)에 대해 **SSH 키 인증 접속(`ssh nas2`)**과 **SMB 네트워크 드라이브 마운트**가 매끄럽게 동작하도록 로컬 환경을 구성하고 검증하라.

# Environment & Target Specifications
- **Client OS:** macOS (zsh 기본 쉘 기준)
- **Target NAS IP:** `192.168.11.2`
- **SSH Host Alias:** `nas2`
- **SSH Port:** `4949`
- **Authentication:** 기존 등록된 SSH Key 기반 비밀번호 없는(Passwordless) 인증 사용 (macOS Keychain 연동)
- **SMB Target:** `smb://192.168.11.2` (포트 445)
- **Network Context:** IPTime 2번 공유기(`192.168.0.x` 대역) 하단 연결 상태

# Step-by-Step Execution Plan

## Phase 1: macOS 네트워크 도달성 및 포트 점검
1. `sw_vers` 및 `ifconfig`로 현재 macOS 버전과 로컬 IP 대역(`192.168.0.x` 여부)을 확인하라.
2. `192.168.11.2`로의 라우팅 경로 및 포트 개방 여부를 점검하라.
   - SSH 포트(`4949`) 점검: `nc -zv -G 3 192.168.11.2 4949`
   - SMB 포트(`445`) 점검: `nc -zv -G 3 192.168.11.2 445`
3. **[예외 처리 및 공유기 가이드]** 만약 포트가 닫혀 있거나 타임아웃(`Operation timed out`)이 발생하면 즉시 작업을 중단하고, 다음 두 가지 중 하나가 필요함을 사용자에게 보고하라:
   - **방안 A (이중 공유기 유지):** IPTime 1번(`192.168.11.1`) 포트포워드 설정에서 `192.168.11.2`의 TCP `4949`, `445` 개방 (별도 회선일 경우 공인 IP/DDNS 주소 필요)
   - **방안 B (네트워크 통합):** IPTime 2번(`192.168.0.1`)을 허브 모드(DHCP 중지 + LAN 포트 연결)로 전환

## Phase 2: macOS SSH Config (`nas2`) 및 Apple Keychain 연동
1. `~/.ssh/` 디렉토리 내 기존 개인키(`id_ed25519`, `id_rsa` 등) 목록을 확인하고 권한을 `chmod 600`으로 보정하라.
2. 기존 `~/.ssh/config` 파일이 존재할 경우 `~/.ssh/config.bak.$(date +%Y%m%d_%H%M%S)`로 백업하라.
3. `~/.ssh/config`에 `Host nas2` 블록을 추가하거나 갱신하라. (macOS 전용 키체인 옵션을 반드시 포함할 것)
   ```text
   Host nas2
       HostName 192.168.11.2
       Port 4949
       User <탐지된_또는_사용자_확인_계정명>
       IdentityFile ~/.ssh/<사용중인_개인키_파일명>
       UseKeychain yes
       AddKeysToAgent yes
       IdentitiesOnly yes
       ServerAliveInterval 60
       ServerAliveCountMax 3
   ```
   *(참고: 계정명이나 키 파일명이 명확하지 않으면 `known_hosts`나 기존 설정을 우선 탐색하고, 불확실할 경우 임의 추측하지 말고 사용자에게 질문하라.)*
4. `ssh-add --apple-use-keychain ~/.ssh/<개인키>`를 실행해 키체인에 키를 등록하고, `ssh -o BatchMode=yes nas2 "uname -a && echo 'SSH_OK'"` 명령으로 비밀번호 없이 즉시 접속되는지 검증하라.

## Phase 3: macOS SMB 연결 및 원클릭 마운트 스크립트 구성
1. `smbutil view //guest@192.168.11.2` 또는 사용자 계정을 통해 NAS에서 제공하는 SMB 공유 폴더 목록을 확인하라. (자격 증명이 필요하면 사용자에게 입력 요청)
2. 사용자가 터미널이나 Spotlight에서 쉽게 NAS를 마운트/언마운트할 수 있도록 `~/bin/mount_nas2.sh` 스크립트(실행 권한 `chmod +x`)를 생성하라.
   - AppleScript(`osascript -e 'mount volume "smb://<계정명>@192.168.11.2/<공유폴더명>"'`) 방식을 사용하면 최초 1회 로그인 시 **macOS 키체인에 비밀번호가 안전하게 암호화 저장**되어 이후 자동 로그인됨.
   - 마운트 확인 경로: `/Volumes/<공유폴더명>`
3. 편의를 위해 `~/.zshrc`에 `alias nas2-mount='~/bin/mount_nas2.sh'` 별칭(Alias)을 추가하고 `source ~/.zshrc`로 반영하라. (수정 전 `.zshrc` 백업 필수)

## Phase 4: 최종 검증 및 리포트
1. `ssh nas2` 접속 테스트 성공 여부 출력
2. `/Volumes/` 하위에 SMB 드라이브 정상 마운트 여부(`df -h | grep 192.168.11.2`) 출력
3. 백업된 설정 파일 위치, 생성된 스크립트 경로, 향후 사용법(`ssh nas2`, `nas2-mount`)을 깔끔하게 요약 보고하라.

# Constraints & Safety Rules
- `~/.ssh/config` 및 `~/.zshrc` 수정 전 반드시 타임스탬프가 포함된 백업 파일을 생성할 것.
- 스크립트 내부에 평문 비밀번호를 절대 하드코딩하지 말고 macOS Keychain(`UseKeychain yes` 및 Finder/osascript 키체인 저장)을 활용할 것.
- 사용자 계정명, SSH 키 파일명, 마운트할 SMB 공유 폴더명이 불명확할 경우 실행을 멈추고 사용자에게 먼저 확인할 것.ß