import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'constants.dart';
import 'remote_log_filter.dart';
import 'remote_log_settings.dart';

/// 업로더 상태(설정 화면 표시용)
class RemoteLogStatus {
  const RemoteLogStatus({
    this.lastSentAt,
    this.lastError,
    this.pendingBytes = 0,
    this.sentLines = 0,
    this.connected,
  });

  final DateTime? lastSentAt;
  final String? lastError;
  final int pendingBytes;
  final int sentLines;
  final bool? connected;
}

/// DMG 앱 내장 원격 로그 업로더.
///
/// - 원본: 로컬 `app.log` (AppLogger가 동기 기록)
/// - 커서: `remote-log-cursor.json` 에 전송 완료 offset 저장 → 서버 불통/앱 재시작에도 유실 없음
/// - 트리거: 로그 이벤트 발생 시 300ms 디바운스, WARN/ERROR는 즉시
/// - 실패: 지수 백오프(1s→60s) 재시도
/// - 필터: 사용자 선택 모드(끄기/오류만/INFO/이벤트/INFO+이벤트/DEBUG/전체/사용자 지정)
class RemoteLogForwarder {
  RemoteLogForwarder._();
  static final RemoteLogForwarder instance = RemoteLogForwarder._();

  static const Duration debounce = Duration(milliseconds: 300);
  static const Duration safetyInterval = Duration(seconds: 15);
  static const Duration loginGrace = Duration(seconds: 10);
  static const int maxLinesPerBatch = 500;
  static const int maxReadBytes = 256 * 1024;
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  late RemoteLogSettings settings;
  final ValueNotifier<RemoteLogStatus> status =
      ValueNotifier(const RemoteLogStatus());

  String _extension = 'unknown';
  final String _session = _newSessionId();
  int _offset = 0;
  DateTime _startedAt = DateTime.now();

  HttpClient? _client;
  StreamSubscription<String>? _sub;
  Timer? _debounceTimer;
  Timer? _safetyTimer;
  Timer? _retryTimer;
  int _backoffSec = 0;
  bool _flushing = false;
  bool _again = false;
  bool _started = false;
  bool _failing = false;
  int _sentLines = 0;

  static String get _cursorPath =>
      '${AppLogger.logDirectory}/remote-log-cursor.json';

  static String _newSessionId() {
    final r = Random();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$ts-${r.nextInt(1 << 32).toRadixString(36)}';
  }

  String get session => _session;
  String get extension => _extension;

  /// 앱 시작 시 1회. AppLogger.init() 이후 호출.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _startedAt = DateTime.now();
    settings = RemoteLogSettings.load();

    // 직전 실행의 미전송분(app-prev.log) 먼저 보충 전송
    await _drainPreviousSession();
    _offset = 0;
    _saveCursor();

    _sub = AppLogger.instance.stream.listen(_onLine);
    _safetyTimer = Timer.periodic(safetyInterval, (_) => requestFlush());
    AppLogger.instance.i(
        '원격 로그 업로더 시작 session=$_session mode=${settings.filter.describe()} url=${settings.url}');
  }

  /// 로그인 성공 시: 내선 번호/도메인 반영
  void onLogin({required String extension, required String domain}) {
    if (extension.isNotEmpty) _extension = extension;
    if (!settings.urlOverridden) {
      settings.url = AppConstants.opsLogUrl(domain);
    }
    requestFlush(immediate: true);
  }

  /// 설정 화면에서 변경 후 저장
  void applySettings(RemoteLogSettings next) {
    settings = next;
    settings.save();
    AppLogger.instance.i(
        '원격 로그 설정 변경 mode=${settings.filter.describe()} url=${settings.url}');
    requestFlush(immediate: true);
  }

  void _onLine(String line) {
    final urgent = line.contains('] ERROR ') || line.contains('] WARN ');
    requestFlush(immediate: urgent);
  }

  void requestFlush({bool immediate = false}) {
    if (!_started) return;
    if (_retryTimer?.isActive == true && !immediate) return; // 백오프 중
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(immediate ? Duration.zero : debounce, () => unawaited(_flush()));
  }

  bool get _waitingForLogin =>
      _extension == 'unknown' &&
      DateTime.now().difference(_startedAt) < loginGrace;

  Future<void> _flush() async {
    if (_flushing) {
      _again = true;
      return;
    }
    if (settings.mode == RemoteLogMode.off) {
      // 끄기 모드: 커서만 끝으로 이동(나중에 켜도 과거분은 보내지 않음)
      _offset = _fileLength(AppLogger.logFilePath);
      _saveCursor();
      _updateStatus();
      return;
    }
    if (_waitingForLogin) {
      _debounceTimer = Timer(loginGrace, () => unawaited(_flush()));
      return;
    }
    _flushing = true;
    try {
      // 한 번에 여러 배치를 drain
      while (true) {
        final batch = _readBatch(AppLogger.logFilePath, _offset);
        if (batch == null) break;
        if (batch.lines.isNotEmpty) {
          final ok = await _post(
            lines: batch.lines,
            session: _session,
            offset: batch.startOffset,
            nextOffset: batch.nextOffset,
            rotated: batch.rotated,
          );
          if (!ok) {
            _scheduleRetry();
            return;
          }
          _sentLines += batch.lines.length;
        }
        _offset = batch.nextOffset;
        _saveCursor();
        if (!batch.more) break;
      }
      _backoffSec = 0;
      _markRecovered();
    } finally {
      _flushing = false;
      _updateStatus();
      if (_again) {
        _again = false;
        requestFlush();
      }
    }
  }

  void _scheduleRetry() {
    _backoffSec = _backoffSec == 0 ? 1 : min(_backoffSec * 2, 60);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _backoffSec), () {
      _retryTimer = null;
      unawaited(_flush());
    });
  }

  void _markRecovered() {
    if (_failing) {
      _failing = false;
      AppLogger.instance.i('원격 로그 전송 복구');
    }
  }

  /// offset부터 완성된 줄만 읽고 필터 적용
  _Batch? _readBatch(String path, int offset) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final length = file.lengthSync();
    var start = offset;
    var rotated = false;
    if (length < start) {
      // 로테이션/절단 감지 → 처음부터
      start = 0;
      rotated = true;
    }
    if (length == start) return null;

    final readLen = min(length - start, maxReadBytes);
    final raf = file.openSync();
    late List<int> bytes;
    try {
      raf.setPositionSync(start);
      bytes = raf.readSync(readLen);
    } finally {
      raf.closeSync();
    }
    final lastNl = bytes.lastIndexOf(10);
    if (lastNl < 0) {
      // 줄 미완성(쓰는 중). 최대치까지 꽉 찬 경우만 강제 진행
      if (readLen < maxReadBytes) return null;
    }
    final usable = lastNl < 0 ? bytes.length : lastNl + 1;
    final text = utf8.decode(bytes.sublist(0, usable), allowMalformed: true);
    final filter = settings.filter;
    final selected = <String>[];
    var consumed = 0;
    var more = (start + usable) < length;
    for (final raw in const LineSplitter().convert(text)) {
      consumed++;
      if (raw.isEmpty) continue;
      if (filter.shouldSend(raw)) selected.add(raw);
      if (selected.length >= maxLinesPerBatch) {
        // 남은 줄은 다음 배치로: 이번 배치에 실제 포함된 바이트까지만 커밋
        final head = const LineSplitter().convert(text).take(consumed).join('\n');
        final headBytes = utf8.encode('$head\n').length;
        return _Batch(selected, start, start + headBytes, true, rotated);
      }
    }
    return _Batch(selected, start, start + usable, more, rotated);
  }

  Future<bool> _post({
    required List<String> lines,
    required String session,
    required int offset,
    required int nextOffset,
    bool rotated = false,
    String? extension,
  }) async {
    // F6: keep-alive 연결이 서버에서 닫힌 경우(HttpException 등) 새 연결로 1회 즉시 재시도
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await _postOnce(
        lines: lines,
        session: session,
        offset: offset,
        nextOffset: nextOffset,
        rotated: rotated,
        extension: extension,
        quiet: attempt == 0,
      );
      if (result != null) return result;
      _client?.close(force: true);
      _client = null;
    }
    return false;
  }

  /// 반환: true=성공, false=HTTP 오류(재시도 무의미), null=연결 오류(재시도 대상)
  Future<bool?> _postOnce({
    required List<String> lines,
    required String session,
    required int offset,
    required int nextOffset,
    required bool rotated,
    required String? extension,
    required bool quiet,
  }) async {
    final url = settings.url;
    if (url.isEmpty) return false;
    try {
      final client = _client ??= (HttpClient()
        ..connectionTimeout = const Duration(seconds: 4));
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      if (settings.key.isNotEmpty) {
        request.headers.add('X-Client-Key', settings.key);
      }
      request.add(utf8.encode(jsonEncode({
        'session': session,
        'extension': extension ?? _extension,
        'host': Platform.localHostname,
        'ip': AppLogger.localIp,
        'app_version': appVersion,
        'mode': settings.filter.describe(),
        'offset': offset,
        'next_offset': nextOffset,
        'rotated': rotated,
        'lines': lines,
      })));
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        status.value = RemoteLogStatus(
          lastSentAt: DateTime.now(),
          pendingBytes: status.value.pendingBytes,
          sentLines: _sentLines + lines.length,
          connected: true,
        );
        return true;
      }
      _recordFailure('http=${response.statusCode}');
      return false;
    } catch (e) {
      if (quiet) return null; // 첫 시도 연결 오류는 조용히 새 연결로 재시도
      _recordFailure(e.runtimeType.toString());
      return null;
    }
  }

  void _recordFailure(String reason) {
    status.value = RemoteLogStatus(
      lastSentAt: status.value.lastSentAt,
      lastError: reason,
      pendingBytes: status.value.pendingBytes,
      sentLines: _sentLines,
      connected: false,
    );
    if (!_failing) {
      _failing = true;
      // 1회만 기록(재시도마다 로그를 남기면 자기 자신을 계속 트리거)
      AppLogger.instance.w('원격 로그 전송 실패 $reason → 로컬 보관 후 재시도');
    }
  }

  void _updateStatus() {
    final pending = max(0, _fileLength(AppLogger.logFilePath) - _offset);
    final s = status.value;
    status.value = RemoteLogStatus(
      lastSentAt: s.lastSentAt,
      lastError: s.lastError,
      pendingBytes: pending,
      sentLines: _sentLines,
      connected: s.connected,
    );
  }

  /// 연결 테스트(설정 화면)
  Future<bool> testConnection() async {
    final ok = await _post(
      lines: const [],
      session: _session,
      offset: _offset,
      nextOffset: _offset,
    );
    if (ok) _markRecovered();
    _updateStatus();
    return ok;
  }

  static int _fileLength(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  void _saveCursor() {
    try {
      File(_cursorPath).writeAsStringSync(jsonEncode({
        'session': _session,
        'extension': _extension,
        'offset': _offset,
      }));
    } catch (_) {}
  }

  /// 직전 실행 커서가 가리키는 app-prev.log 잔여분 전송
  Future<void> _drainPreviousSession() async {
    try {
      final cursorFile = File(_cursorPath);
      if (!cursorFile.existsSync()) return;
      final json =
          jsonDecode(cursorFile.readAsStringSync()) as Map<String, dynamic>;
      final prevSession = json['session'] as String?;
      final prevExt = (json['extension'] as String?) ?? 'unknown';
      var offset = (json['offset'] as num?)?.toInt() ?? 0;
      if (prevSession == null || settings.mode == RemoteLogMode.off) return;
      for (var i = 0; i < 200; i++) {
        final batch = _readBatch(AppLogger.prevLogFilePath, offset);
        if (batch == null) break;
        if (batch.lines.isNotEmpty) {
          final ok = await _post(
            lines: batch.lines,
            session: prevSession,
            offset: batch.startOffset,
            nextOffset: batch.nextOffset,
            rotated: batch.rotated,
            extension: prevExt,
          );
          if (!ok) return; // 서버 불통: 이전 세션 잔여분은 포기(로컬 app-prev.log 보존)
        }
        offset = batch.nextOffset;
        if (!batch.more) break;
      }
    } catch (_) {}
  }

  void stop() {
    _sub?.cancel();
    _debounceTimer?.cancel();
    _safetyTimer?.cancel();
    _retryTimer?.cancel();
    _client?.close(force: true);
    _client = null;
    _started = false;
  }
}

class _Batch {
  _Batch(this.lines, this.startOffset, this.nextOffset, this.more, this.rotated);
  final List<String> lines;
  final int startOffset;
  final int nextOffset;
  final bool more;
  final bool rotated;
}
