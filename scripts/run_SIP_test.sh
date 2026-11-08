#!/bin/bash
# vite server 서버를 먼저 기동 시킨 후에 테스트함. 그래야 WebRTC가 정상적으로 동작함
''' 
  ➜  Local:   http://localhost:5173/
  ➜  Network: http://192.168.11.39:5173/
  ➜  press h + enter to show help
'''

'''
### 🎯 해결 방안

__이미 검증된 방법으로 진&#xD589;__&#xD558;시면 됩니다:

1. __SIP 등록 테스트__: 위 `register-smoke.mjs` 명령어 실행
2. __인증 검증__: `verify-sip-auth.py` 이미 PASS된 상태
3. __1:1 영상통화 테스트__: 등록 성공 후 진행

__핵심__: 기존에 만들어졌던 `run_SIP_test.sh`, `run_SIP_PRDtest.sh` 스크립트는 현재 디렉토리에 없으며, 사용하실 수 있는 테스트는 `/Users/microdit/Downloads/dev/SmartCC_Kibal-Client/web/scripts/register-smoke.mjs`와 `python3 scripts/verify-sip-auth.py`가 있습니다.

__위 명령어들로 테스트 진&#xD589;__&#xD558;시면 `1102@192.168.11.39` 등록이 성공할 것입니다.
'''

# MacBook Pro에서 (DEV 환경 IP 사용)
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/web
SIP_DOMAIN=192.168.11.39 \
SIP_USERNAME=1102 \
SIP_PASSWORD=1102pass \
SIP_WS_SERVER=ws://192.168.11.39:8088/ws \
node scripts/register-smoke.mjs
# 기대: registered: 1102@192.168.11.39


cd /Users/microdit/Downloads/dev/SmartCC_Kibal
python3 scripts/verify-sip-auth.py
# 기대: PASS: 8 SIP auth objects match





