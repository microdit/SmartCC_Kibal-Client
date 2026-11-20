import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const urls = String.fromEnvironment('TURN_URLS');
  const username = String.fromEnvironment('TURN_USERNAME');
  const credential = String.fromEnvironment('TURN_CREDENTIAL');
  final servers = <Map<String, dynamic>>[
    {
      'urls': urls.isEmpty ? 'turn:192.168.11.5:3478' : urls,
      'username': username,
      'credential': credential,
    },
  ];
  final pc = await createPeerConnection({
    'iceServers': servers,
    'iceTransportPolicy': 'relay',
  });
  pc.onIceCandidate = (c) => stdout.writeln('CANDIDATE ${c.candidate}');
  pc.onIceGatheringState = (s) => stdout.writeln('GATHERING $s');
  await pc.createDataChannel('probe', RTCDataChannelInit());
  await pc.setLocalDescription(await pc.createOffer());
  await Future<void>.delayed(const Duration(seconds: 8));
  stdout.writeln('DONE');
  await pc.close();
  exit(0);
}
