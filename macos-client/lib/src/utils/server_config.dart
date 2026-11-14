import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';

/// 서버 환경설정(SIP 도메인·WS·OPS 주소) — OPS `/api/client/config`에서 자동 갱신.
///
/// 서버(Docker 호스트) IP가 유선/무선 전환 등으로 바뀌어도:
/// 1) 마지막으로 성공한 OPS 주소, 2) mDNS 호스트명(MacPro.local 등), 3) 기본 도메인
/// 순으로 OPS에 접속해 최신 주소를 받아 저장한다.
/// 파일: `<logs>/server-config.json`
class ServerConfig {
  ServerConfig({
    required this.sipDomain,
    required this.sipPort,
    required this.wsServer,
    required this.opsBaseUrl,
    required this.clientLogUrl,
    this.publicHost,
    this.updatedAt,
    this.source = 'default',
    this.clientKey = '',
    this.clientExtension = '',
    this.manifest,
  });

  final String sipDomain;
  final int sipPort;
  final String wsServer;
  final String opsBaseUrl;
  final String clientLogUrl;

  /// 서버 mDNS 호스트명(IP 변경에도 유지되는 부트스트랩 주소)
  final String? publicHost;
  final String? updatedAt;

  /// default | saved | ops
  final String source;

  /// 내선별 클라이언트 키(사용자 수동 입력, ADR-006) — 비어있으면 전역키 fallback
  final String clientKey;
  final String clientExtension;
  /// 서버 manifest(D1): config_version, latest/min_supported, update flags 등
  final Map<String, dynamic>? manifest;

  static String get filePath => '${AppLogger.logDirectory}/server-config.json';

  /// mDNS 기본 부트스트랩 호스트(빌드 시 --dart-define=OPS_BOOTSTRAP_HOST=... 로 변경 가능)
  static const String bootstrapHost =
      String.fromEnvironment('OPS_BOOTSTRAP_HOST', defaultValue: 'MacPro.local');

  factory ServerConfig.defaults() => ServerConfig(
        sipDomain: AppConstants.defaultDomain,
        sipPort: AppConstants.defaultSipPort,
        wsServer: AppConstants.defaultWsServer,
        opsBaseUrl: 'http://${AppConstants.defaultDomain}:${AppConstants.opsPort}',
        clientLogUrl: AppConstants.opsLogUrl(AppConstants.defaultDomain),
        publicHost: bootstrapHost,
      );

  Map<String, dynamic> toJson() => {
        'sipDomain': sipDomain,
        'sipPort': sipPort,
        'wsServer': wsServer,
        'opsBaseUrl': opsBaseUrl,
        'clientLogUrl': clientLogUrl,
        'publicHost': publicHost,
        'updatedAt': updatedAt,
        'clientKey': clientKey,
        'clientExtension': clientExtension,
        'manifest': manifest,
      };

  static ServerConfig? _fromJson(Map<String, dynamic> j, String source) {
    final domain = (j['sipDomain'] ?? j['sip_domain']) as String?;
    final ws = (j['wsServer'] ?? j['ws_server']) as String?;
    if (domain == null || domain.isEmpty || ws == null || ws.isEmpty) return null;
    final ops = (j['opsBaseUrl'] ?? j['ops_base_url']) as String? ??
        'http://$domain:${AppConstants.opsPort}';
    final man = j['manifest'];
    return ServerConfig(
      sipDomain: domain,
      sipPort: ((j['sipPort'] ?? j['sip_port']) as num?)?.toInt() ??
          AppConstants.defaultSipPort,
      wsServer: ws,
      opsBaseUrl: ops,
      clientLogUrl: (j['clientLogUrl'] ?? j['client_log_url']) as String? ??
          '$ops/api/client-logs',
      publicHost: (j['publicHost'] ?? j['public_host']) as String?,
      updatedAt: (j['updatedAt'] ?? j['updated_at']) as String?,
      source: source,
      clientKey: (j['clientKey'] as String?) ?? '',
      clientExtension: (j['clientExtension'] as String?) ?? '',
      manifest: man is Map<String, dynamic> ? man : (man is Map ? Map<String, dynamic>.from(man) : null),
    );
  }

  static ServerConfig load() {
    try {
      final f = File(filePath);
      if (f.existsSync()) {
        final cfg = _fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, 'saved');
        if (cfg != null) return cfg;
      }
    } catch (_) {}
    return ServerConfig.defaults();
  }

  void save() {
    try {
      File(filePath).writeAsStringSync(jsonEncode(toJson()));
    } catch (e) {
      AppLogger.instance.w('서버 설정 저장 실패: $e');
    }
  }

  bool sameAddressAs(ServerConfig other) =>
      sipDomain == other.sipDomain && wsServer == other.wsServer;

  String? get configVersion => manifest?['config_version'] as String?;
  String? get latestVersion => manifest?['latest_version'] as String?;
  String? get minSupportedVersion => manifest?['min_supported_version'] as String?;
  bool get updateRequired => manifest?['update_required'] == true;
  bool get updateRecommended => manifest?['update_recommended'] == true;
  String get releaseNotes => (manifest?['release_notes'] as String?) ?? '';

  ServerConfig copyWith({
    String? sipDomain,
    int? sipPort,
    String? wsServer,
    String? opsBaseUrl,
    String? clientLogUrl,
    String? publicHost,
    String? updatedAt,
    String? source,
    String? clientKey,
    String? clientExtension,
    Map<String, dynamic>? manifest,
  }) => ServerConfig(
        sipDomain: sipDomain ?? this.sipDomain,
        sipPort: sipPort ?? this.sipPort,
        wsServer: wsServer ?? this.wsServer,
        opsBaseUrl: opsBaseUrl ?? this.opsBaseUrl,
        clientLogUrl: clientLogUrl ?? this.clientLogUrl,
        publicHost: publicHost ?? this.publicHost,
        updatedAt: updatedAt ?? this.updatedAt,
        source: source ?? this.source,
        clientKey: clientKey ?? this.clientKey,
        clientExtension: clientExtension ?? this.clientExtension,
        manifest: manifest ?? this.manifest,
      );

  @override
  String toString() =>
      'ServerConfig(domain=$sipDomain ws=$wsServer ops=$opsBaseUrl src=$source)';
}

/// OPS에서 서버 설정을 탐색·갱신
class ServerConfigService {
  ServerConfigService._();
  static final ServerConfigService instance = ServerConfigService._();

  static const Duration perCandidateTimeout = Duration(seconds: 3);

  ServerConfig _current = ServerConfig.load();
  ServerConfig get current => _current;

  /// 탐색 후보 OPS 주소(순서대로 시도)
  List<String> candidates({String? hintDomain}) {
    final c = <String>[
      _current.opsBaseUrl,
      if (hintDomain != null && hintDomain.isNotEmpty)
        'http://$hintDomain:${AppConstants.opsPort}',
      if ((_current.publicHost ?? '').isNotEmpty)
        'http://${_current.publicHost}:${AppConstants.opsPort}',
      'http://${ServerConfig.bootstrapHost}:${AppConstants.opsPort}',
      'http://${AppConstants.defaultDomain}:${AppConstants.opsPort}',
    ];
    final seen = <String>{};
    return [for (final u in c) if (seen.add(u)) u];
  }

  /// OPS에 접속해 최신 설정을 받는다. 성공 시 저장 후 반환, 모두 실패 시 null.
  Future<ServerConfig?> refresh({String? hintDomain, String? clientKey, String? extension}) async {
    final key = clientKey ?? (_current.clientKey.trim().isNotEmpty ? _current.clientKey.trim() : AppConstants.opsClientKey);
    for (final base in candidates(hintDomain: hintDomain)) {
      final cfg = await _fetch(base, key, extension: extension ?? _current.clientExtension);
      if (cfg != null) {
        final changed = !cfg.sameAddressAs(_current) || cfg.configVersion != _current.configVersion;
        _current = cfg;
        cfg.save();
        AppLogger.instance.i('서버 설정 갱신 via=$base '
            'domain=${cfg.sipDomain} ws=${cfg.wsServer} changed=$changed ver=${cfg.configVersion}');
        return cfg;
      }
    }
    AppLogger.instance.w('서버 설정 갱신 실패: OPS 응답 없음 (후보 '
        '${candidates(hintDomain: hintDomain).join(', ')})');
    return null;
  }

  void updateClientCredentials({String? clientKey, String? clientExtension}) {
    _current = _current.copyWith(
      clientKey: clientKey ?? _current.clientKey,
      clientExtension: clientExtension ?? _current.clientExtension,
    );
    _current.save();
  }

  Future<ServerConfig?> _fetch(String base, String key, {String? extension}) async {
    final client = HttpClient()..connectionTimeout = perCandidateTimeout;
    try {
      final req = await client
          .getUrl(Uri.parse('$base/api/client/config'))
          .timeout(perCandidateTimeout);
      final useExt = (extension ?? _current.clientExtension).trim();
      final useKey = key.isNotEmpty ? key : (_current.clientKey.trim().isNotEmpty ? _current.clientKey.trim() : AppConstants.opsClientKey);
      if (useKey.isNotEmpty) req.headers.add('X-Client-Key', useKey);
      if (useExt.isNotEmpty && _current.clientKey.trim().isNotEmpty) {
        req.headers.add('X-Client-Extension', useExt);
      }
      final res = await req.close().timeout(perCandidateTimeout);
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'];
      if (data is! Map<String, dynamic>) return null;
      final fetched = ServerConfig._fromJson(data, 'ops');
      if (fetched == null) return null;
      // 로컬 인증 입력값 유지
      return fetched.copyWith(
        clientKey: _current.clientKey,
        clientExtension: _current.clientExtension,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
