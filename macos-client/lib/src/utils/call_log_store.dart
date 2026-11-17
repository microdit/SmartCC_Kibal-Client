import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';

/// 통화 기록(Call Log) 한 건.
class CallLogEntry {
  const CallLogEntry({
    required this.number,
    required this.at,
    this.direction = 'outgoing',
    this.durationSec = 0,
  });

  final String number;
  final DateTime at;
  final String direction;
  final int durationSec;

  Map<String, dynamic> toJson() => {
        'number': number,
        'at': at.toIso8601String(),
        'direction': direction,
        'durationSec': durationSec,
      };

  static CallLogEntry fromJson(Map<String, dynamic> j) => CallLogEntry(
        number: (j['number'] as String?) ?? '',
        at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
        direction: (j['direction'] as String?) ?? 'outgoing',
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
      );
}

/// 로컬 통화 기록 저장소 (앱 sandbox 계정 디렉터리의 JSON 파일).
/// 플랫폼 공통 구현 - Keychain/SharedPreferences 단독 의존 회피.
class CallLogStore {
  CallLogStore._();
  static final CallLogStore instance = CallLogStore._();

  static const _maxEntries = 100;
  File? _file;

  File get _filePath {
    final f = _file;
    if (f != null) return f;
    final base = AppLogger.logDirectory;
    final dir = Directory(Directory(base).parent.path);
    final created = File('${dir.path}/call_log.json');
    _file = created;
    return created;
  }

  Future<List<CallLogEntry>> load() async {
    try {
      final f = _filePath;
      if (!f.existsSync()) return const [];
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CallLogEntry.fromJson)
          .toList();
    } catch (e) {
      AppLogger.instance.w('CallLog load failed: $e');
      return const [];
    }
  }

  Future<void> add(String number, {String direction = 'outgoing', int durationSec = 0}) async {
    if (number.trim().isEmpty) return;
    try {
      final items = await load();
      items.insert(
          0,
          CallLogEntry(
            number: number.trim(),
            at: DateTime.now(),
            direction: direction,
            durationSec: durationSec,
          ));
      final f = _filePath;
      await f.writeAsString(
        jsonEncode(items.take(_maxEntries).map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.instance.w('CallLog add failed: $e');
    }
  }
}
