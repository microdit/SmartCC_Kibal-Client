#!/bin/bash
# vite server 서버를 먼저 기동 시킨 후에 테스트함. 그래야 WebRTC가 정상적으로 동작함
''' 
  ➜  Local:   http://localhost:5173/
  ➜  Network: http://192.168.11.39:5173/
  ➜  press h + enter to show help
'''

#방법 2: PRD 환경이라면 자격증명 확인
#PRD 서버(`192.168.11.2`)에서 테스트하려면 PRD 전용 자격증명이 필요합니다. 현재 `1102pass`는 DEV 환경용입니다.


cd /Users/microdit/SmartCC_Kibal-Client/web
SIP_DOMAIN=192.168.11.39 \
SIP_USERNAME=1102 \
SIP_PASSWORD=1102pass \
SIP_WS_SERVER=ws://192.168.11.39:8088/ws \
node scripts/register-smoke.mjs
# 기대: registered: 1102@192.168.11.39


