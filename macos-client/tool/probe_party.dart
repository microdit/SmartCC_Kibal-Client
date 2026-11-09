import 'dart:async';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:macos_client/src/sip/sip_client.dart';
import 'package:macos_client/src/sip/sip_config.dart';

/// SIP 프로브용 참가자 (자동 수신 포함)
class ProbeParty {
  ProbeParty({
    required this.label,
    required this.username,
    required this.password,
    required this.domain,
    required this.wsServer,
  });

  final String label;
  final String username;
  final String password;
  final String domain;
  final String wsServer;

  late final KibalSipClient client = KibalSipClient(callback: _onEvent);
  final List<MediaStream> remoteStreams = [];
  bool established = false;
  bool incoming = false;

  Future<bool> start() async {
    final config = SipConfig.webrtc(
      username: username,
      password: password,
      domain: domain,
      port: 8088,
      displayName: 'Kibal Probe $username',
      wsServer: wsServer,
    );

    if (!await client.init(config)) return false;
    return client.register();
  }

  Future<void> stop() async {
    try {
      await client.unregister();
    } catch (_) {}
    await client.disconnect();
    client.dispose();
  }

  Future<void> _onEvent(SipEvent event) async {
    if (event.type == SipEventType.error) {
      stdout.writeln('[$label][error] ${event.error}');
      return;
    }
    if (event.type != SipEventType.call || event.data is! Map) return;

    final data = event.data as Map;
    final action = data['action'];
    stdout.writeln('[$label] $action ${data['target'] ?? ''}');

    switch (action) {
      case 'incoming':
        incoming = true;
        await client.accept();
        break;
      case 'established':
        established = true;
        break;
      case 'terminated':
        established = false;
        break;
      case 'stream':
        final originator = data['originator'] as String? ?? '';
        final stream = data['stream'];
        if (stream is MediaStream && originator.contains('remote')) {
          remoteStreams.add(stream);
          stdout.writeln(
            '[$label] REMOTE STREAM video=${stream.getVideoTracks().length} '
            'audio=${stream.getAudioTracks().length}',
          );
        }
        break;
    }
  }

  void report() {
    stdout.writeln(
      '[$label] established=$established remoteStreams=${remoteStreams.length}',
    );
  }
}
