import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:macos_client/src/sip/sip_client.dart';
import 'package:macos_client/src/sip/sip_config.dart';

/// DEV Asterisk에 대한 SIP REGISTER 스모크 테스트 진입점.
///
/// 실행:
/// flutter run -d macos --debug -t tool/register_probe.dart \
///   --dart-define=SIP_USERNAME=1102 \
///   --dart-define=SIP_PASSWORD=1102pass
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const username = String.fromEnvironment('SIP_USERNAME', defaultValue: '1102');
  const password = String.fromEnvironment('SIP_PASSWORD');
  const domain = String.fromEnvironment('SIP_DOMAIN', defaultValue: '192.168.11.39');
  const wsServer = String.fromEnvironment(
    'SIP_WS_SERVER',
    defaultValue: 'ws://192.168.11.39:8088/ws',
  );

  if (password.isEmpty) {
    stderr.writeln('SIP_PASSWORD dart-define이 필요합니다.');
    exit(2);
  }

  final config = SipConfig.webrtc(
    username: username,
    password: password,
    domain: domain,
    port: 8088,
    displayName: 'Kibal macOS Probe',
    wsServer: wsServer,
  );

  final client = KibalSipClient(
    callback: (event) => stdout.writeln('[event] $event'),
  );

  stdout.writeln('>>> init $username@$domain ($wsServer)');
  final inited = await client.init(config);
  stdout.writeln('>>> init=$inited state=${client.state}');

  var ok = false;
  if (inited) {
    ok = await client.register();
    stdout.writeln('>>> register=$ok state=${client.state}');

    if (ok) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final unregistered = await client.unregister();
      stdout.writeln('>>> unregister=$unregistered state=${client.state}');
    }
  }

  await client.disconnect();
  client.dispose();

  stdout.writeln('>>> RESULT: ${ok ? 'REGISTER_OK' : 'REGISTER_FAIL'}');
  exit(ok ? 0 : 1);
}
