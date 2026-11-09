import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// macOS 카메라/마이크 getUserMedia 격리 검증 진입점.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  stdout.writeln('>>> gum: asking audio+video ...');
  Map<String, dynamic> constraints = {
    'audio': true,
    'video': {
      'facingMode': 'user',
      'width': {'ideal': 1280},
      'height': {'ideal': 720},
    },
  };

  final stream = await navigator.mediaDevices
      .getUserMedia(constraints)
      .timeout(const Duration(seconds: 30), onTimeout: () {
    throw TimeoutException('getUserMedia timed out (30s)');
  });

  final tracks = stream.getTracks();
  for (final t in tracks) {
    stdout.writeln(
        '>>> track id=${t.id} kind=${t.kind} label=${t.label} enabled=${t.enabled}');
  }
  final videoCount = tracks.where((t) => t.kind == 'video').length;
  final audioCount = tracks.where((t) => t.kind == 'audio').length;
  stdout.writeln('>>> video=$videoCount audio=$audioCount');
  stdout.writeln(
      '>>> RESULT: ${videoCount >= 1 && audioCount >= 1 ? 'GUM_OK' : 'GUM_PARTIAL'}');
  exit(0);
}
