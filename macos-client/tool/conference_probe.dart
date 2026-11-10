import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'probe_party.dart';

/// DEV Asterisk ConfBridge(6000) 3자 회의 스모크/S0 비교 테스트.
///
/// 1102/1103/1104가 회의실 6000에 참가하고, 각 참가자가
/// 통화 수립 + 원격 스트림 수신 여부와 audio/video 트랙을 기록합니다.
/// (S0 비교가능성: UI 관측과 분리된 프로브 단위 결과를 명시 출력)
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
  const requireAudio =
      bool.fromEnvironment('REQUIRE_AUDIO', defaultValue: false);
  const exts = String.fromEnvironment('SIP_EXTS', defaultValue: '1102,1103,1104');
  final extList = exts.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  stdout.writeln('>>> CONF PROBE domain=$domain ws=$wsServer room=$room exts=$extList requireAudio=$requireAudio');

  final parties = [
    for (final ext in extList)
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
      final audioSatisfied = !requireAudio || parties.every((p) => p.hasAnyRemoteAudio);
      if (allEstablished && allHaveRemote && audioSatisfied) {
        ok = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    stdout.writeln('>>> REPORT');
    for (final party in parties) {
      party.report();
    }
    final allAudio = parties.every((p) => p.hasAnyRemoteAudio);
    final allVideo = parties.every((p) => p.hasAnyRemoteVideo);
    stdout.writeln('>>> SUMMARY allEstablished=${parties.every((p) => p.established)} '
        'allRemote=${parties.every((p) => p.remoteStreams.isNotEmpty)} '
        'allHasAudio=$allAudio allHasVideo=$allVideo');

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
