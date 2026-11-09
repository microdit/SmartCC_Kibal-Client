import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'probe_party.dart';

/// DEV Asterisk ConfBridge(6000) 3자 회의 스모크 테스트.
///
/// 1102/1103/1104가 회의실 6000에 참가하고, 각 참가자가
/// 통화 수립 + 원격(브리지 믹스) 스트림을 수신하는지 확인합니다.
///
/// 실행:
/// flutter run -d macos --debug -t tool/conference_probe.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const domain = String.fromEnvironment('SIP_DOMAIN', defaultValue: '192.168.11.39');
  const wsServer = String.fromEnvironment(
    'SIP_WS_SERVER',
    defaultValue: 'ws://192.168.11.39:8088/ws',
  );
  const room = String.fromEnvironment('SIP_CONFERENCE_ROOM', defaultValue: '6000');

  final parties = [
    for (final ext in const ['1102', '1103', '1104'])
      ProbeParty(
        label: 'P$ext',
        username: ext,
        password: '${ext}pass',
        domain: domain,
        wsServer: wsServer,
      ),
  ];

  var ok = false;
  try {
    for (final party in parties) {
      if (!await party.start()) {
        throw StateError('REGISTER 실패: ${party.username}');
      }
    }

    for (final party in parties) {
      await party.client.call(room);
    }

    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      final allEstablished = parties.every((p) => p.established);
      final allHaveRemote = parties.every((p) => p.remoteStreams.isNotEmpty);
      if (allEstablished && allHaveRemote) {
        ok = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    for (final party in parties) {
      party.report();
    }

    if (ok) {
      stdout.writeln('>>> 회의 유지 (10초)');
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  } catch (e) {
    stderr.writeln('>>> ERROR: $e');
  } finally {
    for (final party in parties) {
      try {
        if (party.established) await party.client.hangup();
      } catch (_) {}
      await party.stop();
    }
  }

  stdout.writeln('>>> RESULT: ${ok ? 'CONFERENCE_OK' : 'CONFERENCE_FAIL'}');
  exit(ok ? 0 : 1);
}
