import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_logger.dart';
import 'constants.dart';

enum ConnectionProfile { dev, prd, external }

extension ConnectionProfileX on ConnectionProfile {
  String get label {
    switch (this) {
      case ConnectionProfile.dev:
        return 'DEV';
      case ConnectionProfile.prd:
        return 'PRD';
      case ConnectionProfile.external:
        return '외부망';
    }
  }

  ServerConfig defaultConfig() {
    switch (this) {
      case ConnectionProfile.dev:
        return ServerConfig(
          sipDomain: '192.168.11.5',
          sipPort: 5060,
          wsServer: 'ws://192.168.11.5:8088/ws',
          opsBaseUrl: 'http://192.168.11.5:8091',
          clientLogUrl: AppConstants.opsLogUrl('192.168.11.5'),
          source: 'profile',
        );
      case ConnectionProfile.prd:
        return ServerConfig(
          sipDomain: '192.168.11.3',
          sipPort: 5060,
          wsServer: 'ws://192.168.11.3:8088/ws',
          opsBaseUrl: 'http://192.168.11.3:8091',
          clientLogUrl: AppConstants.opsLogUrl('192.168.11.3'),
          source: 'profile',
        );
      case ConnectionProfile.external:
        return ServerConfig(
          sipDomain: 'appletreeda.synology.me',
          sipPort: 8089,
          wsServer: 'wss://appletreeda.synology.me:8089/ws',
          opsBaseUrl: 'http://appletreeda.synology.me:8091',
          clientLogUrl:
              'http://appletreeda.synology.me:${AppConstants.opsPort}/api/client-logs',
          secure: false,
          source: 'profile',
        );
    }
  }

  List<String> get candidates {
    switch (this) {
      case ConnectionProfile.dev:
        return const [
          'http://192.168.11.5:8091',
          'http://MacPro.local:8091',
        ];
      case ConnectionProfile.prd:
        return const [
          'http://192.168.11.3:8091',
          'http://nas2:8091',
        ];
      case ConnectionProfile.external:
        return const [
          'http://appletreeda.synology.me:8091',
        ];
    }
  }
}

class ConnectionProfileStore {
  ConnectionProfileStore._();

  static final ConnectionProfileStore instance = ConnectionProfileStore._();

  static String get path =>
      '${AppLogger.logDirectory}/connection-profiles.json';

  Map<String, dynamic> _data = {};

  Future<void> load() async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        _data = {};
        return;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) _data = decoded;
    } catch (_) {
      _data = {};
    }
  }

  ConnectionProfile get selected {
    final name = _data['selected'] as String?;
    return ConnectionProfile.values.firstWhere(
      (p) => p.name == name,
      orElse: () => ConnectionProfile.dev,
    );
  }

  void setSelected(ConnectionProfile profile) {
    _data['selected'] = profile.name;
    _save();
  }

  ServerConfig? configFor(ConnectionProfile profile) {
    final raw = _data[profile.name];
    if (raw is! Map<String, dynamic>) return null;
    return ServerConfig._fromJson(raw, 'profile');
  }

  void save(ConnectionProfile profile, ServerConfig config) {
    final map = <String, dynamic>{
      'sipDomain': config.sipDomain,
      'sipPort': config.sipPort,
      'wsServer': config.wsServer,
      'opsBaseUrl': config.opsBaseUrl,
      'clientLogUrl': config.clientLogUrl,
      'secure': config.secure,
    };
    _data[profile.name] = map;
    _save();
  }

  void _save() {
    try {
      File(path).writeAsStringSync(jsonEncode(_data));
    } catch (e) {
      AppLogger.instance.w('연결 프로필 저장 실패: $e');
    }
  }
}

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
    this.secure = false,
    this.manifest,
    this.turn,
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

  final bool secure;

  /// 서버 manifest(D1): config_version, latest/min_supported, update flags 등
  final Map<String, dynamic>? manifest;

  final Map<String, dynamic>? turn;

  static String get filePath => '${AppLogger.logDirectory}/server-config.json';

  /// mDNS 기본 부트스트랩 호스트(빌드 시 --dart-define=OPS_BOOTSTRAP_HOST=... 로 변경 가능)
  static const String bootstrapHost = String.fromEnvironment(
      'OPS_BOOTSTRAP_HOST',
      defaultValue: 'MacPro.local');

  factory ServerConfig.defaults() => ServerConfig(
        sipDomain: AppConstants.defaultDomain,
        sipPort: AppConstants.defaultSipPort,
        wsServer: AppConstants.defaultWsServer,
        opsBaseUrl:
            'http://${AppConstants.defaultDomain}:${AppConstants.opsPort}',
        clientLogUrl: AppConstants.opsLogUrl(AppConstants.defaultDomain),
        publicHost: bootstrapHost,
      );

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
        'sipDomain': sipDomain,
        'sipPort': sipPort,
        'wsServer': wsServer,
        'opsBaseUrl': opsBaseUrl,
        'clientLogUrl': clientLogUrl,
        'publicHost': publicHost,
        'updatedAt': updatedAt,
        'secure': secure,
        // 보안: Ops 클라이언트 키/인증내선은 기본적으로 평문 설정파일에 저장하지 않음(보안 저장소 사용)
        if (includeSecrets) 'clientKey': clientKey,
        if (includeSecrets) 'clientExtension': clientExtension,
        'manifest': manifest,
      };

  static ServerConfig? _fromJson(Map<String, dynamic> j, String source) {
    final domain = (j['sipDomain'] ?? j['sip_domain']) as String?;
    final ws = (j['wsServer'] ?? j['ws_server']) as String?;
    if (domain == null || domain.isEmpty || ws == null || ws.isEmpty) {
      return null;
    }
    final ops = (j['opsBaseUrl'] ?? j['ops_base_url']) as String? ??
        'http://$domain:${AppConstants.opsPort}';
    final man = j['manifest'];
    final secureValue = j['secure'] ?? j['use_tls'] ?? j['tls'];
    final secure = secureValue is bool
        ? secureValue
        : secureValue is String
            ? secureValue.toLowerCase() == 'true' || secureValue == '1'
            : secureValue == 1;
    final cfg = ServerConfig(
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
      secure: secure,
      manifest: man is Map<String, dynamic>
          ? man
          : (man is Map ? Map<String, dynamic>.from(man) : null),
    );
    return cfg;
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
      File(filePath)
          .writeAsStringSync(jsonEncode(toJson(includeSecrets: false)));
    } catch (e) {
      AppLogger.instance.w('서버 설정 저장 실패: $e');
    }
  }

  bool sameAddressAs(ServerConfig other) =>
      sipDomain == other.sipDomain && wsServer == other.wsServer;

  String? get configVersion => manifest?['config_version'] as String?;
  String? get latestVersion => manifest?['latest_version'] as String?;
  String? get minSupportedVersion =>
      manifest?['min_supported_version'] as String?;
  bool get updateRequired => manifest?['update_required'] == true;
  bool get updateRecommended => manifest?['update_recommended'] == true;
  String get releaseNotes => (manifest?['release_notes'] as String?) ?? '';

  /// DEV 보안통신 전환 지원: http<->https, ws<->wss 베이스 전환 헬퍼(명시 설정 우선)
  ServerConfig withScheme({required bool secure}) {
    String toSecureHttp(String u) =>
        u.startsWith('http://') ? 'https://${u.substring(7)}' : u;
    String toPlainHttp(String u) =>
        u.startsWith('https://') ? 'http://${u.substring(8)}' : u;
    String toSecureWs(String u) =>
        u.startsWith('ws://') ? 'wss://${u.substring(5)}' : u;
    String toPlainWs(String u) =>
        u.startsWith('wss://') ? 'ws://${u.substring(6)}' : u;
    if (secure) {
      return copyWith(
        opsBaseUrl: toSecureHttp(opsBaseUrl),
        clientLogUrl: toSecureHttp(clientLogUrl),
        wsServer: toSecureWs(wsServer),
      );
    }
    return copyWith(
      opsBaseUrl: toPlainHttp(opsBaseUrl),
      clientLogUrl: toPlainHttp(clientLogUrl),
      wsServer: toPlainWs(wsServer),
    );
  }

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
    bool? secure,
    Map<String, dynamic>? manifest,
    Map<String, dynamic>? turn,
  }) =>
      ServerConfig(
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
        secure: secure ?? this.secure,
        manifest: manifest ?? this.manifest,
        turn: turn ?? this.turn,
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

  void setCurrent(ServerConfig cfg) {
    _current = cfg;
  }

  Future<ServerConfig?> probeProfile(
    ConnectionProfile profile, {
    String? clientKey,
    String? extension,
  }) async {
    final key = (clientKey ?? _current.clientKey).trim().isNotEmpty
        ? (clientKey ?? _current.clientKey).trim()
        : AppConstants.opsClientKey;
    for (final base in profile.candidates) {
      final cfg = await _fetch(
        base,
        key,
        extension: extension ?? _current.clientExtension,
      );
      if (cfg != null) {
        final resolved = profile == ConnectionProfile.external
            ? profile.defaultConfig().copyWith(
                  clientKey: cfg.clientKey,
                  clientExtension: cfg.clientExtension,
                  publicHost: cfg.publicHost,
                  updatedAt: cfg.updatedAt,
                  source: cfg.source,
                  manifest: cfg.manifest,
                  turn: cfg.turn,
                )
            : cfg;
        _current = resolved;
        resolved.save();
        AppLogger.instance
            .i('연결 프로필 자동설정 성공 profile=${profile.name} via=$base');
        return resolved;
      }
    }
    AppLogger.instance.w('연결 프로필 자동설정 실패 profile=${profile.name}');
    return null;
  }

  /// 탐색 후보 OPS 주소(순서대로 시도)
  List<String> candidates({String? hintDomain}) {
    // OPS는 HTTP-only. HTTPS URL이 저장된 경우 HTTP로 정규화하여 hang 방지.
    String toHttp(String u) => u.replaceFirst(RegExp(r'^https://', caseSensitive: false), 'http://');
    final c = <String>[
      toHttp(_current.opsBaseUrl),
      if (hintDomain != null && hintDomain.isNotEmpty)
        'http://$hintDomain:${AppConstants.opsPort}',
      if ((_current.publicHost ?? '').isNotEmpty)
        'http://${_current.publicHost}:${AppConstants.opsPort}',
      'http://${ServerConfig.bootstrapHost}:${AppConstants.opsPort}',
      'http://${AppConstants.defaultDomain}:${AppConstants.opsPort}',
    ];
    final seen = <String>{};
    return [
      for (final u in c)
        if (seen.add(u)) u
    ];
  }

  /// OPS에 접속해 최신 설정을 받는다. 성공 시 저장 후 반환, 모두 실패 시 null.
  Future<ServerConfig?> refresh(
      {String? hintDomain, String? clientKey, String? extension}) async {
    final key = clientKey ??
        (_current.clientKey.trim().isNotEmpty
            ? _current.clientKey.trim()
            : AppConstants.opsClientKey);
    for (final base in candidates(hintDomain: hintDomain)) {
      final cfg = await _fetch(base, key,
          extension: extension ?? _current.clientExtension);
      if (cfg != null) {
        final changed = !cfg.sameAddressAs(_current) ||
            cfg.configVersion != _current.configVersion;
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

  Future<ServerConfig?> _fetch(String base, String key,
      {String? extension}) async {
    final client = HttpClient()..connectionTimeout = perCandidateTimeout;
    try {
      client.badCertificateCallback =
          (cert, host, port) => true; // DEV self-signed
      final req = await client
          .getUrl(Uri.parse('$base/api/client/config'))
          .timeout(perCandidateTimeout);
      final useExt = (extension ?? _current.clientExtension).trim();
      final useKey = key.isNotEmpty
          ? key
          : (_current.clientKey.trim().isNotEmpty
              ? _current.clientKey.trim()
              : AppConstants.opsClientKey);
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
      final turnRaw = data['turn'];
      final turn = turnRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(turnRaw)
          : null;
      // 로컬 인증 입력값 유지
      return fetched.copyWith(
        clientKey: _current.clientKey,
        clientExtension: _current.clientExtension,
        turn: turn,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
