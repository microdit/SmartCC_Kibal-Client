import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 전역 실행 로그.
///
/// - 파일로 영구 기록: `$HOME/Library/Application Support/com.microdit.macosClient/logs/app.log`
/// - 직전 실행 로그는 `app-prev.log`로 보관 (1세대)
/// - macOS 네이티브 로그 창(창 > 실행 로그 보기)이 이 파일을 실시간 갱신 표시
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  /// 동기 append 핸들. IOSink 버퍼링 없이 즉시 디스크 반영 →
  /// 원격 업로더가 offset 기준으로 바로 읽을 수 있다.
  RandomAccessFile? _raf;
  File? _file;

  /// 현재 로컬 IP(원격 업로더 식별용)
  static String get localIp => _localIp;
  static String get identity => _identity;
  final _buffer = <String>[];
  final _controller = StreamController<String>.broadcast();

  // 스팸 방지: 동일(level+message) 로그는 5초 내 반복 시 생략
  static const int dedupeWindowMs = 5000;
  String? _lastSignature;
  DateTime _lastSignatureAt = DateTime.now();
  int _dedupeCount = 0;

  static const int maxBufferLines = 800;
  static const int maxFileBytes = 2 * 1024 * 1024;

  static String get logDirectory {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/Library/Application Support/com.microdit.macosClient/logs';
  }

  static String get logFilePath => '$logDirectory/app.log';
  static String get prevLogFilePath => '$logDirectory/app-prev.log';

  /// 세션 식별 정보 — 누가(user@domain), 어느 장치(host/ip)인지 모든 로그에 prefix
  static String _identity = 'usr=- host=- ip=-';
  static final Set<String> _issuedTags = <String>{};

  /// 로그인/등록 성공 시 호출: 이후 모든 로그에 [usr=... host=... ip=...] prefix 사용
  static void setIdentity({String? user, String? domain}) {
    final tag = '${user ?? '-'}@${domain ?? '-'}';
    if (!_issuedTags.contains(tag)) {
      _issuedTags.clear();
      _issuedTags.add(tag);
    }
    _identity = 'usr=$tag host=${Platform.localHostname} ip=$_localIp';
  }

  static String _localIp = '-';
  static Future<void> discoverLocalIp() async {
    // 소켓 접속 방식은 8.8.8.8(리모트)이 찍히는 문제 → 로컬 NIC 열거로 교정
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final nic in interfaces) {
        for (final addr in nic.addresses) {
          if (!addr.isLoopback) {
            _localIp = addr.address;
            return;
          }
        }
      }
      _localIp = 'unresolved';
    } catch (_) {
      _localIp = 'unresolved';
    }
  }

  Future<void> init() async {
    try {
      final dir = Directory(logDirectory);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File(logFilePath);
      if (file.existsSync()) {
        final prev = File(prevLogFilePath);
        if (prev.existsSync()) prev.deleteSync();
        file.renameSync(prevLogFilePath);
      }
      _file = file;
      _raf = file.openSync(mode: FileMode.append);
      await discoverLocalIp();
      i('AppLogger 초기화 완료 file=$logFilePath identity=$_identity mode=${kDebugMode ? 'debug' : 'release'}');
    } catch (e) {
      // 로깅 실패가 앱 동작을 막지 않도록 조용히 건너뜀
      logToConsole('로그 파일 초기화 실패: $e');
    }
  }

  /// 네이티브 창 등 뷰어가 구독하는 실시간 스트림.
  Stream<String> get stream => _controller.stream;

  /// 화면 표시/복사용 최근 로그.
  List<String> get recentLines => List.unmodifiable(_buffer);

  static void logToConsole(String message) {
    // ignore: avoid_print
    print(message);
  }

  void i(String message) => _write('INFO', '[$_identity] $message');
  void w(String message) => _write('WARN', '[$_identity] $message');
  void e(String message) => _write('ERROR', '[$_identity] $message');

  /// UI 사용자 행위 추적 (screen, action, 파라미터)
  void ui(String screen, String action,
      {Map<String, Object?> params = const {}}) {
    final p = params.isEmpty ? '' : ' params=${_flat(params)}';
    _write('EVENT', 'UI $screen action=$action$p');
  }

  /// 상태 머신/이벤트 추적
  void evt(String domain, String event,
      {String? state, Map<String, Object?> details = const {}}) {
    final d = details.isEmpty ? '' : ' ${_flat(details)}';
    _write('EVENT', '$domain event=$event state=${state ?? '-'}$d');
  }

  /// 통화 관련 구조화 로그 (함수/결과/인자)
  void call(String op,
      {String? target, String? state, Map<String, Object?> params = const {}}) {
    final p = params.isEmpty ? '' : ' params=${_flat(params)}';
    _write('EVENT', 'SIP op=$op target=${target ?? '-'} state=${state ?? '-'}$p');
  }

  /// 상세 디버그 (네이티브 뷰어에서 필터로 조회)
  void d(String message) => _write('DEBUG', '[$_identity] $message');

  String _flat(Map<String, Object?> params) {
    return params.entries
        .map((e) => '${e.key}=${e.value ?? '-'}')
        .join(' ');
  }

  void _write(String level, String message) {
    final now = DateTime.now();
    final signature = '$level|$message';
    if (signature == _lastSignature &&
        now.difference(_lastSignatureAt).inMilliseconds < dedupeWindowMs) {
      _dedupeCount += 1;
      return;
    }
    if (_dedupeCount > 0) {
      final skipped = _dedupeCount;
      _lastSignature = null;
      _lastSignatureAt = now;
      _dedupeCount = 0;
      _pushInternal('INFO', '(동일 로그 ${skipped + 1}회 반복 스킵 요약)');
    }
    _lastSignature = signature;
    _lastSignatureAt = now;
    _pushInternal(level, message);
  }

  void _pushInternal(String level, String message) {
    final stamp = DateTime.now().toIso8601String();
    final line = '[$stamp] $level $message';
    _buffer.add(line);
    if (_buffer.length > maxBufferLines) {
      _buffer.removeRange(0, _buffer.length - maxBufferLines);
    }
    // 파일에 먼저 동기 기록한 뒤 스트림 통지(업로더가 즉시 읽을 수 있게)
    _fileWrite(line);
    logToConsole('${stamp.substring(11)} $level $message');
    _controller.add(line);
  }

  void _fileWrite(String line) {
    try {
      final raf = _raf;
      if (raf != null) raf.writeStringSync('$line\n');
      _rotateIfNeeded();
    } catch (_) {}
  }

  void _rotateIfNeeded() {
    final file = _file;
    if (file == null) return;
    try {
      final len = _raf?.lengthSync() ?? file.lengthSync();
      if (len < maxFileBytes) return;
      // 파일 크기 초과 시 마지막 400행만 남기고 다시 씀 (업로더는 길이 축소를 감지해 offset 리셋)
      final content = file.readAsLinesSync();
      final keep =
          content.sublist(content.length > 400 ? content.length - 400 : 0);
      _raf?.closeSync();
      final buffer = StringBuffer('--- [rotate] 크기 초과로 앞부분 잘림 ---\n');
      for (final l in keep) {
        buffer.writeln(l);
      }
      file.writeAsStringSync(buffer.toString(), mode: FileMode.write);
      _raf = file.openSync(mode: FileMode.append);
    } catch (_) {}
  }

  /// 프로덕션에서 누락되는 Dart 런타임/프레임워크 오류까지 파일로 기록.
  void hookGlobalErrors() {
    FlutterError.onError = (details) {
      e('FlutterError: ${details.exceptionAsString()}');
      final stack = details.stack;
      if (stack != null) e('  at $stack');
      // 기존 프레임워크 동작 유지
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      e('UnhandledError: $error');
      e('  at $stack');
      return true;
    };
  }
}
