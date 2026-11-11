/// 원격 로그 전송 필터.
///
/// 로컬 app.log에는 항상 전체를 기록하고, 서버 업로드 시에만 이 필터를 적용한다.
/// 라인 형식: `[ISO8601] LEVEL message` (EVENT는 `EVENT <DOMAIN> ...`)
enum RemoteLogMode {
  off('끄기'),
  errors('오류만'),
  info('INFO'),
  events('이벤트(msg)'),
  infoEvents('INFO + 이벤트'),
  debug('DEBUG'),
  all('전체'),
  custom('사용자 지정');

  const RemoteLogMode(this.label);
  final String label;

  static RemoteLogMode fromName(String? name) => RemoteLogMode.values
      .firstWhere((m) => m.name == name, orElse: () => RemoteLogMode.infoEvents);
}

const List<String> kLogLevels = ['ERROR', 'WARN', 'INFO', 'EVENT', 'DEBUG'];
const List<String> kEventDomains = ['SIP', 'MEDIA', 'UI', 'DIALER', 'LOGIN'];

class RemoteLogFilter {
  const RemoteLogFilter({
    required this.mode,
    this.levels = const {'ERROR', 'WARN', 'INFO', 'EVENT'},
    this.domains = const {'SIP', 'MEDIA', 'UI', 'DIALER', 'LOGIN'},
    this.includeStats = false,
  });

  final RemoteLogMode mode;
  final Set<String> levels; // 사용자 지정 전용
  final Set<String> domains; // 사용자 지정 전용(EVENT 도메인)
  final bool includeStats; // SIP stats 5초 통계 포함 여부

  static final RegExp _lineRe =
      RegExp(r'^\[[^\]]+\]\s+(INFO|WARN|ERROR|DEBUG|EVENT)\s+(.*)$');

  /// (level, rest) 파싱. 형식 불일치(예: 스택 연속 줄)는 null.
  static (String, String)? parse(String line) {
    final m = _lineRe.firstMatch(line);
    if (m == null) return null;
    return (m.group(1)!, m.group(2)!);
  }

  bool shouldSend(String line) {
    if (mode == RemoteLogMode.off) return false;
    if (mode == RemoteLogMode.all) return true;

    final parsed = parse(line);
    // 형식 밖 줄(스택트레이스 연속 등)은 오류 맥락이므로 off 외에는 전송
    if (parsed == null) return mode != RemoteLogMode.errors;
    final level = parsed.$1;
    final rest = parsed.$2;
    final isStats = level == 'DEBUG' && rest.contains('SIP stats inbound');

    switch (mode) {
      case RemoteLogMode.errors:
        return level == 'ERROR' || level == 'WARN';
      case RemoteLogMode.info:
        return level == 'ERROR' || level == 'WARN' || level == 'INFO';
      case RemoteLogMode.events:
        return level == 'ERROR' || level == 'WARN' || level == 'EVENT';
      case RemoteLogMode.infoEvents:
        return level != 'DEBUG';
      case RemoteLogMode.debug:
        return isStats ? includeStats : true;
      case RemoteLogMode.custom:
        if (!levels.contains(level)) return false;
        if (isStats && !includeStats) return false;
        if (level == 'EVENT') {
          final domain = rest.split(' ').first;
          return domains.contains(domain);
        }
        return true;
      case RemoteLogMode.off:
      case RemoteLogMode.all:
        return mode == RemoteLogMode.all;
    }
  }

  /// 서버 표시용 모드 설명
  String describe() {
    if (mode != RemoteLogMode.custom) {
      return mode == RemoteLogMode.debug && includeStats
          ? '${mode.label}+stats'
          : mode.label;
    }
    final lv = levels.join(',');
    final dm = domains.join(',');
    return '사용자 지정[$lv|$dm${includeStats ? '|stats' : ''}]';
  }
}
