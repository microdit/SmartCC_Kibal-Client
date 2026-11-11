import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';

/// 로컬 app.log와 동일한 로그 라인을 OPS 콘솔로 실시간 배출한다.
///
/// `AppLogger.instance.stream`(브로드캐스트)을 구독해 라인을 버퍼에 쌓고,
/// 일정 주기로 `POST /api/client-logs`(X-Client-Key)에 배치 전송한다.
/// 네트워크 실패는 조용히 무시하며, 로컬 파일 로깅에는 영향을 주지 않는다.
class RemoteLogForwarder {
  RemoteLogForwarder._();
  static final RemoteLogForwarder instance = RemoteLogForwarder._();

  String? _url;
  String? _key;
  String _extension = 'unknown';
  HttpClient? _client;
  StreamSubscription<String>? _sub;
  Timer? _flushTimer;
  final List<String> _pending = [];
  bool _flushing = false;
  bool _started = false;

  static const int maxBuffer = 500;
  static const Duration flushInterval = Duration(seconds: 2);
  static const Duration connectTimeout = Duration(seconds: 4);
  static const Duration requestTimeout = Duration(seconds: 5);

  /// 시작. 이미 시작된 상태면 url/key/extension을 갱신한다(로그인 시 재호출).
  void start({required String url, required String key, String? extension}) {
    _url = url;
    _key = key;
    if (extension != null && extension.isNotEmpty) _extension = extension;
    if (_started) return;
    _started = true;
    _sub = AppLogger.instance.stream.listen((line) {
      _pending.add(line);
      if (_pending.length > maxBuffer) {
        _pending.removeRange(0, _pending.length - maxBuffer);
      }
    });
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
    AppLogger.instance.i('원격 로그 전달 시작 url=$url ext=$_extension');
  }

  void setExtension(String extension) {
    if (extension.isNotEmpty) _extension = extension;
  }

  Future<void> flush() async {
    if (_flushing || _pending.isEmpty || _url == null) return;
    _flushing = true;
    final batch = List<String>.from(_pending);
    _pending.clear();
    final url = _url!;
    final key = _key;

    try {
      final client = _client ??= (HttpClient()
        ..connectionTimeout = connectTimeout);
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      if (key != null && key.isNotEmpty) {
        request.headers.add('X-Client-Key', key);
      }
      request.add(utf8.encode(jsonEncode({
        'extension': _extension,
        'lines': batch,
      })));
      final response = await request.close().timeout(requestTimeout);
      await response.drain<void>();
      if (response.statusCode >= 300) {
        AppLogger.instance.w('원격 로그 전달 실패 http=${response.statusCode}');
      }
    } catch (_) {
      // 네트워크/서버 미기동 시 로컬 파일에는 이미 기록됨 → 조용히 무시
    } finally {
      _flushing = false;
    }
  }

  void stop() {
    _sub?.cancel();
    _flushTimer?.cancel();
    _client?.close(force: true);
    _client = null;
    _started = false;
  }
}
