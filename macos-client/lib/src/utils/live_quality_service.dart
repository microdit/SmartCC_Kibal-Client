import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class LiveQualitySnapshot {
  LiveQualitySnapshot({
    required this.at,
    required this.videoResolution,
    required this.videoCodec,
    required this.audioCodec,
    required this.videoFps,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
    required this.videoPacketsLost,
    required this.audioPacketsLost,
    required this.freezeCount,
    required this.pliCount,
    required this.nackCount,
    required this.jitterMs,
    required this.rttMs,
    required this.availableOutgoingKbps,
    required this.candidateState,
    required this.avgVideoFps,
    required this.avgVideoBitrateKbps,
    required this.avgAudioBitrateKbps,
    required this.avgRttMs,
    required this.avgJitterMs,
  });

  final DateTime at;
  final String videoResolution;
  final String videoCodec;
  final String audioCodec;
  final double videoFps;
  final double videoBitrateKbps;
  final double audioBitrateKbps;
  final int videoPacketsLost;
  final int audioPacketsLost;
  final int freezeCount;
  final int pliCount;
  final int nackCount;
  final double jitterMs;
  final double rttMs;
  final double availableOutgoingKbps;
  final String candidateState;
  final double avgVideoFps;
  final double avgVideoBitrateKbps;
  final double avgAudioBitrateKbps;
  final double avgRttMs;
  final double avgJitterMs;

  String get verdict {
    if (candidateState.isNotEmpty &&
        candidateState != 'succeeded' &&
        candidateState != 'completed') {
      return 'ICE 점검 중';
    }
    if (videoPacketsLost > 100 || audioPacketsLost > 50) return '품질 저하';
    if (videoFps > 0 && videoFps < 20) return '프레임 저하';
    return '양호';
  }
}

class LiveQualityService {
  LiveQualityService._();

  static final LiveQualityService instance = LiveQualityService._();

  final ValueNotifier<LiveQualitySnapshot?> snapshot = ValueNotifier(null);

  Future<List<Map<String, dynamic>>> Function()? _provider;
  Timer? _timer;
  DateTime? _lastAt;
  final Map<String, int> _prevBytes = {};
  final List<LiveQualitySnapshot> _history = [];

  bool get isRunning => _timer?.isActive ?? false;

  void start({required Future<List<Map<String, dynamic>>> Function() provider}) {
    if (isRunning) return;
    _provider = provider;
    _lastAt = null;
    _prevBytes.clear();
    _history.clear();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_tick()));
    unawaited(_tick());
    AppLogger.instance.i('실시간 품질 진단 시작');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _prevBytes.clear();
    snapshot.value = null;
    AppLogger.instance.i('실시간 품질 진단 중지');
  }

  static double _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  Future<void> _tick() async {
    final provider = _provider;
    if (provider == null) return;
    try {
      final reports = await provider();
      final now = DateTime.now();
      final seconds = _lastAt == null
          ? 1.0
          : now.difference(_lastAt!).inMilliseconds / 1000.0;
      _lastAt = now;

      final codecNames = <int, String>{};
      for (final report in reports) {
        if ((report['type'] as String?) != 'codec') continue;
        final v = report['values'];
        if (v is! Map) continue;
        final id = (v['payloadType'] as num?)?.toInt();
        final mime = (v['mimeType'] as String?) ?? '';
        if (id != null && mime.isNotEmpty) codecNames[id] = mime.split('/').last;
      }

      String videoResolution = '-';
      String videoCodec = '-';
      String audioCodec = '-';
      double videoFps = 0;
      double videoLost = 0;
      double audioLost = 0;
      double freeze = 0;
      double pli = 0;
      double nack = 0;
      double jitter = 0;
      double rtt = 0;
      double availableOut = 0;
      String candidateState = '';
      double videoBitrate = 0;
      double audioBitrate = 0;

      for (final report in reports) {
        final type = (report['type'] as String?) ?? '';
        final v = report['values'];
        if (v is! Map) continue;

        if (type == 'candidate-pair') {
          candidateState = (v['state'] as String?) ?? '';
          rtt = ((v['currentRoundTripTime'] as num?)?.toDouble() ?? 0) * 1000;
          availableOut =
              ((v['availableOutgoingBitrate'] as num?)?.toDouble() ?? 0) / 1000;
          continue;
        }
        if (type != 'inbound-rtp' && type != 'outbound-rtp') continue;

        final kind = (v['kind'] ?? v['mediaType'] ?? '').toString();
        final isVideo = kind == 'video';
        final codecId = (v['codec'] as num?)?.toInt();
        final codecName = codecId != null ? codecNames[codecId] : null;
        final bytesKey = type == 'outbound-rtp' ? 'bytesSent' : 'bytesReceived';
        final bytes = ((v[bytesKey] as num?) ?? 0).toInt();
        final prev = _prevBytes['$type:$kind'] ?? bytes;
        final rate = seconds > 0 ? (bytes - prev) * 8 / seconds / 1000 : 0.0;
        _prevBytes['$type:$kind'] = bytes;

        if (type == 'outbound-rtp') {
          if (isVideo) {
            final w = (v['frameWidth'] as num?)?.toInt();
            final h = (v['frameHeight'] as num?)?.toInt();
            if (w != null && h != null) videoResolution = '${w}x$h';
            videoFps = (v['framesPerSecond'] as num?)?.toDouble() ?? 0;
            videoCodec = codecName ?? ((v['codec'] as String?) ?? '-');
            videoBitrate = rate;
          } else {
            audioCodec = codecName ?? ((v['codec'] as String?) ?? '-');
            audioBitrate = rate;
          }
        } else if (isVideo) {
          videoLost = (v['packetsLost'] as num?)?.toDouble() ?? 0;
          freeze = (v['freezeCount'] as num?)?.toDouble() ?? 0;
          pli = (v['pliCount'] as num?)?.toDouble() ?? 0;
          nack = (v['nackCount'] as num?)?.toDouble() ?? 0;
        } else {
          audioLost = (v['packetsLost'] as num?)?.toDouble() ?? 0;
          jitter = ((v['jitter'] as num?)?.toDouble() ?? 0) * 1000;
        }
      }

      final next = LiveQualitySnapshot(
        at: now,
        videoResolution: videoResolution,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        videoFps: videoFps,
        videoBitrateKbps: videoBitrate,
        audioBitrateKbps: audioBitrate,
        videoPacketsLost: videoLost.toInt(),
        audioPacketsLost: audioLost.toInt(),
        freezeCount: freeze.toInt(),
        pliCount: pli.toInt(),
        nackCount: nack.toInt(),
        jitterMs: jitter,
        rttMs: rtt,
        availableOutgoingKbps: availableOut,
        candidateState: candidateState,
        avgVideoFps: _avg([..._history.map((s) => s.videoFps), videoFps]),
        avgVideoBitrateKbps:
            _avg([..._history.map((s) => s.videoBitrateKbps), videoBitrate]),
        avgAudioBitrateKbps:
            _avg([..._history.map((s) => s.audioBitrateKbps), audioBitrate]),
        avgRttMs: _avg([..._history.map((s) => s.rttMs), rtt]),
        avgJitterMs: _avg([..._history.map((s) => s.jitterMs), jitter]),
      );
      _history.add(next);
      if (_history.length > 60) _history.removeAt(0);
      snapshot.value = next;
    } catch (e) {
      AppLogger.instance.w('실시간 품질 수집 실패: $e');
    }
  }
}
