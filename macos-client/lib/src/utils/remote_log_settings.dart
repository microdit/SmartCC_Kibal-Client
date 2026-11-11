import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';
import 'remote_log_filter.dart';

/// 원격 로그 전송 설정 (JSON 파일 저장, 추가 의존성 없음)
///
/// 파일: `<logs>/remote-log-settings.json`
/// 기본값: 빌드 시 `--dart-define=OPS_LOG_URL=... --dart-define=OPS_CLIENT_KEY=...`,
/// 없으면 DEV 상수.
class RemoteLogSettings {
  RemoteLogSettings({
    required this.mode,
    required this.url,
    required this.key,
    required this.levels,
    required this.domains,
    required this.includeStats,
    this.urlOverridden = false,
  });

  RemoteLogMode mode;
  String url;
  String key;
  Set<String> levels;
  Set<String> domains;
  bool includeStats;

  /// 사용자가 서버 주소를 직접 바꿨는지(로그인 도메인 자동 반영 중단)
  bool urlOverridden;

  static const String _defineUrl = String.fromEnvironment('OPS_LOG_URL');
  static const String _defineKey = String.fromEnvironment('OPS_CLIENT_KEY');

  static String get defaultUrl => _defineUrl.isNotEmpty
      ? _defineUrl
      : AppConstants.opsLogUrl(AppConstants.defaultDomain);
  static String get defaultKey =>
      _defineKey.isNotEmpty ? _defineKey : AppConstants.opsClientKey;

  static String get filePath =>
      '${AppLogger.logDirectory}/remote-log-settings.json';

  factory RemoteLogSettings.defaults() => RemoteLogSettings(
        mode: RemoteLogMode.infoEvents,
        url: defaultUrl,
        key: defaultKey,
        levels: {'ERROR', 'WARN', 'INFO', 'EVENT'},
        domains: kEventDomains.toSet(),
        includeStats: false,
      );

  RemoteLogFilter get filter => RemoteLogFilter(
        mode: mode,
        levels: levels,
        domains: domains,
        includeStats: includeStats,
      );

  static RemoteLogSettings load() {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return RemoteLogSettings.defaults();
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final d = RemoteLogSettings.defaults();
      return RemoteLogSettings(
        mode: RemoteLogMode.fromName(json['mode'] as String?),
        url: (json['url'] as String?)?.trim().isNotEmpty == true
            ? json['url'] as String
            : d.url,
        key: (json['key'] as String?) ?? d.key,
        levels: ((json['levels'] as List?)?.cast<String>().toSet()) ?? d.levels,
        domains:
            ((json['domains'] as List?)?.cast<String>().toSet()) ?? d.domains,
        includeStats: json['includeStats'] as bool? ?? false,
        urlOverridden: json['urlOverridden'] as bool? ?? false,
      );
    } catch (_) {
      return RemoteLogSettings.defaults();
    }
  }

  void save() {
    try {
      File(filePath).writeAsStringSync(jsonEncode({
        'mode': mode.name,
        'url': url,
        'key': key,
        'levels': levels.toList(),
        'domains': domains.toList(),
        'includeStats': includeStats,
        'urlOverridden': urlOverridden,
      }));
    } catch (e) {
      AppLogger.instance.w('로그 전송 설정 저장 실패: $e');
    }
  }
}
