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

  IOSink? _sink;
  File? _file;
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
      _sink = file.openWrite(mode: FileMode.append);
      i('AppLogger 초기화 완료 ($logFilePath)');
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

  void i(String message) => _write('INFO', message);
  void w(String message) => _write('WARN', message);
  void e(String message) => _write('ERROR', message);

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
    unawaited(_sinkWrite(line, stamp, level, message));
    _controller.add(line);
  }

  Future<void> _sinkWrite(
      String line, String stamp, String level, String message) async {
    try {
      final sink = _sink;
      if (sink != null) sink.writeln(line);
      await _rotateIfNeeded();
    } catch (_) {}
    logToConsole('${stamp.substring(11)} $level $message');
  }

  Future<void> _rotateIfNeeded() async {
    final file = _file;
    if (file == null) return;
    try {
      final len = file.lengthSync();
      if (len < maxFileBytes) return;
      // 파일 크기 초과 시 마지막 400행만 남기고 다시 씀
      final content = file.readAsLinesSync();
      final keep =
          content.sublist(content.length > 400 ? content.length - 400 : 0);
      final rawSink = _sink;
      if (rawSink != null) {
        await rawSink.close();
      }
      _sink = file.openWrite(mode: FileMode.write); // truncate 모드
      _sink?.writeln('--- [rotate] 크기 초과로 앞부분 잘림 ---');
      for (final l in keep) {
        _sink?.writeln(l);
      }
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
