import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'constants.dart';
import 'server_config.dart';

/// 회의 참가자(서버 ConfBridge 기준) — OPS `/api/conference/<room>/participants`
class ConferenceParticipant {
  ConferenceParticipant({
    required this.channel,
    required this.extension,
    required this.displayName,
    required this.hasVideo,
    required this.isSelf,
  });

  final String channel;
  final String extension;

  /// 앱 로그인 시 입력한 표시 이름. 없으면 내선 번호.
  final String displayName;
  final bool hasVideo;
  final bool isSelf;

  /// 카드 라벨: "표시이름 (내선)" — 표시 이름이 내선과 같으면 내선만
  String get label =>
      displayName.isEmpty || displayName == extension ? extension : '$displayName ($extension)';

  static ConferenceParticipant? fromJson(Map<String, dynamic> j) {
    final ch = j['channel'] as String?;
    final ext = j['extension'] as String?;
    if (ch == null || ext == null) return null;
    return ConferenceParticipant(
      channel: ch,
      extension: ext,
      displayName: (j['display_name'] as String?)?.trim() ?? ext,
      hasVideo: j['has_video'] == true,
      isSelf: j['self'] == true,
    );
  }
}

class ConferenceSnapshot {
  const ConferenceSnapshot(this.participants, this.videoOrder);
  final List<ConferenceParticipant> participants;

  /// 내 원격 영상 m-line 순서(채널명)
  final List<String> videoOrder;

  int get count => participants.length;
}

/// OPS 연동: 표시 이름 보고 + 회의 참가자 폴링
class ConferenceParticipantService extends ChangeNotifier {
  ConferenceParticipantService._();
  static final ConferenceParticipantService instance = ConferenceParticipantService._();

  static const Duration interval = Duration(seconds: 5);

  Timer? _timer;
  String? _room;
  String _extension = '';
  ConferenceSnapshot? _snapshot;
  String _lastSummary = '';

  ConferenceSnapshot? get snapshot => _snapshot;

  String get _base => ServerConfigService.instance.current.opsBaseUrl;

  /// 로그인 시 표시 이름 보고(비어 있으면 서버가 내선 번호로 표시)
  Future<void> reportProfile({required String extension, String? displayName}) async {
    _extension = extension;
    await _send('POST', '/api/client/profile', body: {
      'extension': extension,
      'display_name': displayName ?? '',
      'host': Platform.localHostname,
    });
  }

  void start(String room, {required String extension}) {
    if (_room == room && _timer != null) return;
    stop();
    _room = room;
    _extension = extension;
    unawaited(_poll());
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _room = null;
    _lastSummary = '';
    if (_snapshot != null) {
      _snapshot = null;
      notifyListeners();
    }
  }

  Future<void> _poll() async {
    final room = _room;
    if (room == null) return;
    final json = await _send('GET',
        '/api/conference/$room/participants?extension=${Uri.encodeQueryComponent(_extension)}');
    if (_room != room) return;
    final data = json?['data'];
    if (data is! Map<String, dynamic>) return;
    final list = <ConferenceParticipant?>[
      for (final p in (data['participants'] as List? ?? const []))
        if (p is Map<String, dynamic>) ConferenceParticipant.fromJson(p),
    ].whereType<ConferenceParticipant>().toList();
    final order = [for (final c in (data['video_order'] as List? ?? const [])) '$c'];
    _snapshot = ConferenceSnapshot(list, order);
    final summary = list.map((p) => '${p.label}:${p.hasVideo ? 'V' : 'A'}${p.isSelf ? '*' : ''}').join(',');
    if (summary != _lastSummary) {
      _lastSummary = summary;
      AppLogger.instance.i('CONFERENCE participants room=$room n=${list.length} [$summary]');
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.openUrl(method, Uri.parse('$_base$path'))
          .timeout(const Duration(seconds: 3));
      req.headers.add('X-Client-Key', AppConstants.opsClientKey);
      if (body != null) {
        req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 4));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
