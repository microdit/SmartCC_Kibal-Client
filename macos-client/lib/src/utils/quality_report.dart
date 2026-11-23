import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';
import 'server_config.dart';

enum QualityVerdict { good, warning, critical }

class QualityMetrics {
  QualityMetrics({
    required this.extension,
    required this.videoSamples,
    required this.mediaSamples,
    required this.avgFps,
    required this.avgVideoKB,
    required this.vLostDelta,
    required this.freezeDelta,
    required this.pliDelta,
    required this.keyframeDelta,
    required this.decodedDelta,
    required this.audioLostDelta,
    required this.fpsSeries,
    required this.vLostSeries,
    required this.freezeSeries,
    required this.pliSeries,
    this.resolution,
    this.iceState,
    this.ip,
    required this.verdict,
    required this.findings,
    required this.recommendations,
    this.firstAt,
    this.lastAt,
  });

  final String extension;
  final int videoSamples;
  final int mediaSamples;
  final double avgFps;
  final double avgVideoKB;
  final int vLostDelta;
  final int freezeDelta;
  final int pliDelta;
  final int keyframeDelta;
  final int decodedDelta;
  final int audioLostDelta;
  final List<double> fpsSeries;
  final List<double> vLostSeries;
  final List<double> freezeSeries;
  final List<double> pliSeries;
  final String? resolution;
  final String? iceState;
  final String? ip;
  final QualityVerdict verdict;
  final List<String> findings;
  final List<String> recommendations;
  final DateTime? firstAt;
  final DateTime? lastAt;

  String get verdictLabel {
    switch (verdict) {
      case QualityVerdict.good:
        return '양호';
      case QualityVerdict.warning:
        return '주의';
      case QualityVerdict.critical:
        return '위험';
    }
  }

  static QualityMetrics fromLogs({
    required String extension,
    required List<String> videoLines,
    required List<String> mediaLines,
  }) {
    final vTimes = <DateTime>[];
    int? firstVLost, lastVLost, firstFreeze, lastFreeze, firstPli, lastPli;
    int? firstKey, lastKey, firstDecoded, lastDecoded;
    int? prevVLost, prevFreeze, prevPli;
    final fps = <double>[];
    final vLostSeries = <double>[];
    final freezeSeries = <double>[];
    final pliSeries = <double>[];
    String? resolution;

    for (final line in videoLines) {
      final t = _timeOf(line);
      if (t != null) vTimes.add(t);
      final vLost = _intAfter(line, 'vLost=');
      final freeze = _intAfter(line, 'freeze=');
      final pli = _intAfter(line, 'pli=');
      final key = _intAfter(line, 'keyframes=');
      final decoded = _intAfter(line, 'decodedFrames+');
      if (vLost != null) {
        firstVLost ??= vLost;
        final delta = prevVLost == null || vLost < prevVLost ? 0 : vLost - prevVLost;
        vLostSeries.add(delta.toDouble());
        prevVLost = vLost;
        lastVLost = vLost;
      }
      if (freeze != null) {
        firstFreeze ??= freeze;
        final delta =
            prevFreeze == null || freeze < prevFreeze ? 0 : freeze - prevFreeze;
        freezeSeries.add(delta.toDouble());
        prevFreeze = freeze;
        lastFreeze = freeze;
      }
      if (pli != null) {
        firstPli ??= pli;
        final delta = prevPli == null || pli < prevPli ? 0 : pli - prevPli;
        pliSeries.add(delta.toDouble());
        prevPli = pli;
        lastPli = pli;
      }
      if (key != null) {
        firstKey ??= key;
        lastKey = key;
      }
      if (decoded != null) {
        firstDecoded ??= decoded;
        lastDecoded = decoded;
      }
      final res = RegExp(r'in=(\d+x\d+)@').firstMatch(line);
      if (res != null) resolution = res.group(1);
      final f = RegExp(r'@(\d+)fps').firstMatch(line);
      if (f != null) fps.add(double.tryParse(f.group(1)!) ?? 0);
    }

    final mTimes = <DateTime>[];
    final kb = <double>[];
    int? firstAudioLost, lastAudioLost;
    String? iceState;
    String? ip;
    int videoTracks = 1;

    for (final line in mediaLines) {
      final t = _timeOf(line);
      if (t != null) mTimes.add(t);
      final v = _intAfter(line, 'videoKB=');
      if (v != null) kb.add(v.toDouble());
      final aLost = _intAfter(line, 'audioLost=');
      if (aLost != null) {
        firstAudioLost ??= aLost;
        lastAudioLost = aLost;
      }
      final ice = RegExp(r'ice=RTCIceConnectionState(\w+)').firstMatch(line);
      if (ice != null) iceState = ice.group(1);
      final addr = RegExp(r'ip=(\d+\.\d+\.\d+\.\d+)').firstMatch(line);
      if (addr != null) ip = addr.group(1);
      final tracks = RegExp(r'videoTracks=(\d+)/(\d+)').firstMatch(line);
      if (tracks != null) videoTracks = int.tryParse(tracks.group(2)!) ?? 1;
    }

    final vLostDelta = (lastVLost ?? 0) - (firstVLost ?? 0);
    final freezeDelta = (lastFreeze ?? 0) - (firstFreeze ?? 0);
    final pliDelta = (lastPli ?? 0) - (firstPli ?? 0);
    final keyframeDelta = (lastKey ?? 0) - (firstKey ?? 0);
    final decodedDelta = (lastDecoded ?? 0) - (firstDecoded ?? 0);
    final audioLostDelta = (lastAudioLost ?? 0) - (firstAudioLost ?? 0);
    final avgFps = fps.isEmpty
        ? 0.0
        : fps.reduce((a, b) => a + b) / fps.length;
    final avgVideoKB = kb.isEmpty
        ? 0.0
        : kb.reduce((a, b) => a + b) / kb.length;

    final findings = <String>[];
    final recommendations = <String>[];
    late QualityVerdict verdict;

    if (videoTracks == 0 ||
        (iceState != null &&
            iceState != 'Completed' &&
            iceState != 'Connected')) {
      verdict = QualityVerdict.critical;
      findings.add('원격 영상 트랙이 없거나 ICE가 $iceState 상태입니다.');
      recommendations.add('회의실에서 나갔다 재입장하고 SIP 등록 상태를 확인하세요.');
    } else if (vLostDelta > 100 || freezeDelta > 50 || pliDelta > 50) {
      verdict = QualityVerdict.critical;
      findings.add('영상 패킷 유실($vLostDelta)과 프리즈($freezeDelta)/PLI($pliDelta)가 큽니다.');
      recommendations.add('유선 또는 5GHz 링크로 전환하고 단말 무선 상태를 점검하세요.');
    } else if (vLostDelta > 0 || freezeDelta > 10 || pliDelta > 10 ||
        (avgFps > 0 && avgFps < 25)) {
      verdict = QualityVerdict.warning;
      findings.add('수신 프레임이 불규칙하거나 경미한 영상 손실이 있습니다.');
      recommendations.add('링크 품질을 관찰하고 필요 시 유선으로 전환하세요.');
    } else {
      verdict = QualityVerdict.good;
      findings.add('영상·음성 수신 상태가 안정적입니다.');
      recommendations.add('현재 설정을 유지하세요.');
    }
    if (audioLostDelta > 0) {
      findings.add('오디오 패킷 유실 $audioLostDelta건이 검출되었습니다.');
    }

    final allTimes = [...vTimes, ...mTimes]..sort();
    return QualityMetrics(
      extension: extension,
      videoSamples: videoLines.length,
      mediaSamples: mediaLines.length,
      avgFps: avgFps,
      avgVideoKB: avgVideoKB,
      vLostDelta: vLostDelta,
      freezeDelta: freezeDelta,
      pliDelta: pliDelta,
      keyframeDelta: keyframeDelta,
      decodedDelta: decodedDelta,
      audioLostDelta: audioLostDelta,
      fpsSeries: fps,
      vLostSeries: vLostSeries,
      freezeSeries: freezeSeries,
      pliSeries: pliSeries,
      resolution: resolution,
      iceState: iceState,
      ip: ip,
      verdict: verdict,
      findings: findings,
      recommendations: recommendations,
      firstAt: allTimes.isEmpty ? null : allTimes.first,
      lastAt: allTimes.isEmpty ? null : allTimes.last,
    );
  }

  static DateTime? _timeOf(String line) {
    final m = RegExp(r'^\[([^\]]+)\]').firstMatch(line);
    if (m == null) return null;
    return DateTime.tryParse(m.group(1)!);
  }

  static int? _intAfter(String line, String key) {
    final i = line.indexOf(key);
    if (i < 0) return null;
    final rest = line.substring(i + key.length);
    final m = RegExp(r'^\d+').firstMatch(rest);
    if (m == null) return null;
    return int.tryParse(m.group(0)!);
  }
}

class QualityReportService {
  QualityReportService._();

  static const _timeout = Duration(seconds: 6);

  static Future<QualityMetrics> fetch({
    required String extension,
    String? baseUrl,
    String? key,
  }) async {
    final base = baseUrl ?? ServerConfigService.instance.current.opsBaseUrl;
    final cfg = ServerConfigService.instance.current;
    final useKey = (key ?? cfg.clientKey).trim().isNotEmpty
        ? (key ?? cfg.clientKey).trim()
        : AppConstants.opsClientKey;
    final videoLines = await _fetchLines(base, extension, 'video summary', useKey);
    final mediaLines = await _fetchLines(base, extension, 'media summary', useKey);
    AppLogger.instance.i(
        '품질지표 수집 ext=$extension video=${videoLines.length} media=${mediaLines.length}');
    return QualityMetrics.fromLogs(
      extension: extension,
      videoLines: videoLines,
      mediaLines: mediaLines,
    );
  }

  static Future<List<String>> _fetchLines(
      String base, String extension, String query, String key) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      client.badCertificateCallback = (cert, host, port) => true;
      final uri = Uri.parse(
          '$base/api/client-logs?extension=${Uri.encodeComponent(extension)}'
          '&tail=200&q=${Uri.encodeComponent(query)}');
      final req = await client.getUrl(uri).timeout(_timeout);
      req.headers.add('X-Client-Key', key);
      req.headers.add('X-Client-Extension', extension);
      final res = await req.close().timeout(_timeout);
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'];
      if (data is! Map<String, dynamic>) return const [];
      final lines = data['lines'];
      if (lines is! List) return const [];
      return lines.whereType<String>().toList();
    } catch (e) {
      AppLogger.instance.w('품질지표 조회 실패: $query ($e)');
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}
