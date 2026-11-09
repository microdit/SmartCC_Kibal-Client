import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'probe_party.dart';

/// DEV Asterisk에서 1102 → 1103 자동 1:1 영상통화 스모크 테스트.
///
/// 실행:
/// flutter run -d macos --debug -t tool/call_probe.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const domain = String.fromEnvironment('SIP_DOMAIN', defaultValue: '192.168.11.39');
  const wsServer = String.fromEnvironment(
    'SIP_WS_SERVER',
    defaultValue: 'ws://192.168.11.39:8088/ws',
  );

  final caller = ProbeParty(
    label: 'CALLER',
    username: const String.fromEnvironment('SIP_CALLER', defaultValue: '1102'),
    password: const String.fromEnvironment('SIP_CALLER_PASSWORD', defaultValue: '1102pass'),
    domain: domain,
    wsServer: wsServer,
  );
  final callee = ProbeParty(
    label: 'CALLEE',
    username: const String.fromEnvironment('SIP_CALLEE', defaultValue: '1103'),
    password: const String.fromEnvironment('SIP_CALLEE_PASSWORD', defaultValue: '1103pass'),
    domain: domain,
    wsServer: wsServer,
  );

  var ok = false;
  try {
    if (!await caller.start() || !await callee.start()) {
      throw StateError('REGISTER 실패');
    }

    await caller.client.call(callee.username);

    // 통화 수립 + 양방향 원격 스트림 대기
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      if (caller.established &&
          callee.established &&
          caller.remoteStreams.isNotEmpty &&
          callee.remoteStreams.isNotEmpty) {
        ok = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    caller.report();
    callee.report();

    if (ok) {
      // 미디어가 실제로 흐르는지 5초간 유지
      await Future<void>.delayed(const Duration(seconds: 5));
      await caller.client.hangup();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } catch (e) {
    stderr.writeln('>>> ERROR: $e');
  } finally {
    await caller.stop();
    await callee.stop();
  }

  stdout.writeln('>>> RESULT: ${ok ? 'CALL_OK' : 'CALL_FAIL'}');
  exit(ok ? 0 : 1);
}

