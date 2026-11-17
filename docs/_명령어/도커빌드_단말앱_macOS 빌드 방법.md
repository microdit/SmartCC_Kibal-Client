[일반]
cd /Users/microdit/Downloads/dev/SmartCC_Kibal/deploy/dev
docker compose up -d --build ops asterisk

[강제]
docker compose up -d --build ops asterisk --force-recreate

#도커 #도커재시작 #도커빌드 #docker #build #dockerbuid 
[DevExpert]23:21
compose.yaml이 deploy/dev/에 있습니다. 아래처럼 실행하세요.
cd /Users/microdit/Downloads/dev/SmartCC_Kibal/deploy/dev
docker compose up -d --build ops asterisk
(또는 루트에서 docker compose -f deploy/dev/compose.yaml up -d --build ops asterisk)
재빌드/재생성으로 kibal-dev-ops, kibal-dev-asterisk가 재시작되어 활성 통화에 영향이 있을 수 있습니다. 완료 후 docker compose ps와 curl -s http://192.168.0.3:8091/api/session로 확인하세요.

[단말 앱 빌드]
cd SmartCC_Kibal-Client/macos-client && flutter pub get && flutter run -d macos

[DevExpert]23:28
cd /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/macos-client && flutter pub get && flutter run -d macos
[DevExpert]23:30
빌드
./scripts/build_macos.sh release

릴리즈
./scripts/release_macos.sh

[DevExpert]23:34
[다른 macOS , 다른 맥, 다른 Mac 에서 소스 땡겨와 빌드]
## 3. 다른 Mac에서 직접 빌드 (권장 — Gatekeeper 경고 없음)

bash
cd ~/Downloads/dev/SmartCC_Kibal-Client && git pull
cd macos-client && ./scripts/release_macos.sh --no-bump --install
'open /Applications/macos_client.app'
open /Users/microdit/Downloads/dev/SmartCC_Kibal-Client/macos-client/build/macos/Build/Products/Release/macos_client.app