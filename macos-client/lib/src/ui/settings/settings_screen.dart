import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/media_provider.dart';
import '../../providers/sip_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/client_auth_state.dart';
import '../../utils/connection_test.dart';
import '../../utils/constants.dart';
import '../../utils/ops_directory.dart';
import '../../utils/remote_log_forwarder.dart';
import '../../utils/remote_log_settings.dart';
import '../../utils/server_config.dart';
import '../../utils/video_quality_settings.dart';
import 'remote_log_settings_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authExt = TextEditingController();
  final _authKey = TextEditingController();
  final _domain = TextEditingController();
  final _port = TextEditingController();
  final _ws = TextEditingController();
  final _ops = TextEditingController();

  bool _loading = true;
  bool _verifying = false;
  bool _saving = false;
  String? _verifyMsg;
  bool _lastVerifyOffline = false;
  ClientAuthState _auth = ClientAuthState.empty();
  late VideoQualitySettings _quality;
  String? _qualityMsg;
  late ConnectionProfile _profile;
  String? _autoMsg;
  bool _testing = false;
  List<ConnectionTestResult> _testResults = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = await ClientAuthStore.instance().load();
    final store = ConnectionProfileStore.instance;
    await store.load();
    _profile = store.selected;
    final cfg = store.configFor(_profile) ?? _profile.defaultConfig();
    _quality = VideoQualitySettings.load();
    if (!mounted) return;
    setState(() {
      _domain.text = cfg.sipDomain;
      _port.text = cfg.sipPort.toString();
      _ws.text = cfg.wsServer;
      _ops.text = cfg.opsBaseUrl;
      _authExt.text = auth.authExtension;
      _authKey.text = auth.clientKey;
      _auth = auth;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _authExt.dispose();
    _authKey.dispose();
    _domain.dispose();
    _port.dispose();
    _ws.dispose();
    _ops.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResults = const [];
      _autoMsg = null;
    });
    final base = ServerConfigService.instance.current;
    final cfg = base.copyWith(
      sipDomain: _domain.text.trim(),
      sipPort: int.tryParse(_port.text.trim()) ?? base.sipPort,
      wsServer: _ws.text.trim(),
      opsBaseUrl: _ops.text.trim(),
      clientLogUrl: '${_ops.text.trim()}/api/client-logs',
      source: 'test',
    );
    final results = await ConnectionTestService.instance.test(
      profile: _profile,
      config: cfg,
      clientKey: _authKey.text.trim(),
      extension: _authExt.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResults = results;
      _autoMsg = results.any((r) => r.ok)
          ? '연결 테스트 완료 — 결과를 확인하세요.'
          : '모든 경로가 실패했습니다. 설정/방화벽을 확인하세요.';
    });
  }

  void _applyLogUrl(ServerConfig cfg) {
    final s = RemoteLogForwarder.instance.settings;
    RemoteLogForwarder.instance.applySettings(RemoteLogSettings(
      mode: s.mode,
      url: cfg.clientLogUrl,
      key: s.key,
      levels: s.levels,
      domains: s.domains,
      includeStats: s.includeStats,
      urlOverridden: true,
      autoSend: s.autoSend,
    ));
  }

  Future<void> _switchProfile(ConnectionProfile profile) async {
    final base = ServerConfigService.instance.current;
    final current = base.copyWith(
      sipDomain: _domain.text.trim(),
      sipPort: int.tryParse(_port.text.trim()) ?? base.sipPort,
      wsServer: _ws.text.trim(),
      opsBaseUrl: _ops.text.trim(),
      source: 'profile',
    );
    final store = ConnectionProfileStore.instance;
    store.save(_profile, current);
    store.setSelected(profile);
    final cfg = store.configFor(profile) ?? profile.defaultConfig();
    ServerConfigService.instance.setCurrent(cfg);
    cfg.save();
    _applyLogUrl(cfg);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _domain.text = cfg.sipDomain;
      _port.text = cfg.sipPort.toString();
      _ws.text = cfg.wsServer;
      _ops.text = cfg.opsBaseUrl;
      _autoMsg = '${profile.label} 프로필로 전환했습니다.';
    });
  }

  Future<void> _autoConfigure() async {
    setState(() => _autoMsg = '서버 설정을 탐색하는 중…');
    final cfg = await ServerConfigService.instance.probeProfile(
      _profile,
      clientKey: _authKey.text.trim(),
      extension: _authExt.text.trim(),
    );
    if (!mounted) return;
    if (cfg == null) {
      setState(() => _autoMsg = '연결되는 서버가 없습니다. 수동으로 입력하세요.');
      return;
    }
    ConnectionProfileStore.instance.save(_profile, cfg);
    ConnectionProfileStore.instance.setSelected(_profile);
    _applyLogUrl(cfg);
    setState(() {
      _domain.text = cfg.sipDomain;
      _port.text = cfg.sipPort.toString();
      _ws.text = cfg.wsServer;
      _ops.text = cfg.opsBaseUrl;
      _autoMsg = '서버에서 자동 설정을 받았습니다 (${cfg.source}).';
    });
  }

  Future<void> _saveConnection() async {
    setState(() => _saving = true);
    final domain = _domain.text.trim();
    final wsInput = _ws.text.trim();
    final external = domain.contains('synology.me') || wsInput.contains('synology.me');
    var wsServer = wsInput;
    if (external) {
      if (wsServer.isEmpty) {
        wsServer = 'wss://$domain:8089/ws';
      } else {
        wsServer = wsServer
            .replaceFirst('ws://', 'wss://')
            .replaceFirst(':8088/ws', ':8089/ws');
      }
      _ws.text = wsServer;
    }
    final cfg = ServerConfigService.instance.current.copyWith(
      sipDomain: domain,
      sipPort: int.tryParse(_port.text.trim()) ?? AppConstants.defaultSipPort,
      wsServer: wsServer,
      opsBaseUrl: _ops.text.trim(),
      clientLogUrl: '${_ops.text.trim()}/api/client-logs',
      secure: external || ServerConfigService.instance.current.secure,
      source: 'saved',
    );
    ServerConfigService.instance
        .setCurrent(cfg); // ignore: invalid_use_of_visible_for_testing_member
    cfg.save();
    _applyLogUrl(cfg);
    ConnectionProfileStore.instance.save(_profile, cfg);
    ConnectionProfileStore.instance.setSelected(_profile);
    AppLogger.instance.ui('SETTINGS', 'connectionSaved', params: {
      'profile': _profile.name,
      'domain': cfg.sipDomain,
      'secureWs': cfg.wsServer.startsWith('wss'),
      'secureOps': cfg.opsBaseUrl.startsWith('https'),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('연결 설정을 저장했습니다.')));
  }

  Future<void> _verifyAuth() async {
    final ext = _authExt.text.trim();
    final key = _authKey.text.trim();
    if (ext.isEmpty || key.isEmpty) {
      setState(() => _verifyMsg = '인증 내선과 OPS 클라이언트 키를 모두 입력하세요.');
      return;
    }
    setState(() {
      _verifying = true;
      _verifyMsg = '서버 검증 중...';
      _lastVerifyOffline = false;
    });
    await ClientAuthStore.instance().applyInput(extension: ext, clientKey: key);
    final base = _ops.text.trim().isNotEmpty
        ? _ops.text.trim()
        : ServerConfigService.instance.current.opsBaseUrl;
    final result = await _verifyAgainstServer(base, ext, key);
    ClientAuthState st;
    if (result.ok) {
      st = await ClientAuthStore.instance().markVerified();
      // 인증 성공 시 주소록/설정 즉시 갱신
      await ServerConfigService.instance.refresh(
          hintDomain: _domain.text.trim(), clientKey: key, extension: ext);
      await OpsDirectory.fetch();
      _verifyMsg = '인증됨: 서버 검증 성공 ($ext)';
      AppLogger.instance.evt('AUTH', 'verifyResult',
          state: 'verified', details: {'ext': ext});
    } else {
      if (result.message == '서버 연결 실패') {
        _lastVerifyOffline = true;
      }
      st = await ClientAuthStore.instance().markFailed(reason: result.message);
      if (st.failCount >= ClientAuthState.maxFailCount) {
        _authKey.clear();
        _authExt.clear();
        _verifyMsg = st.lastError ??
            '10회 오류로 초기화되었습니다. 서버 관리자 확인이 필요합니다(자동 폐기 아님). 다시 인증번호를 입력하세요.';
      } else {
        final remain = ClientAuthState.maxFailCount - st.failCount;
        _verifyMsg =
            '검증 실패: ${result.message} (실패 ${st.failCount}/10, 남은 $remain회 · 10회 도달 시 인증정보 초기화)';
      }
      AppLogger.instance.evt('AUTH', 'verifyResult', state: 'failed', details: {
        'ext': ext,
        'failCount': st.failCount,
        'status': result.statusCode,
        'reason': result.message,
      });
      _postAuthFailLog(
          ext: ext,
          failCount: st.failCount,
          status: result.statusCode,
          reset: st.failCount >= ClientAuthState.maxFailCount);
    }
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _auth = st;
    });
  }

  Future<void> _verifyOffline() async {
    final ext = _authExt.text.trim();
    final key = _authKey.text.trim();
    if (ext.isEmpty || key.isEmpty) {
      setState(() => _verifyMsg = '인증 내선과 OPS 클라이언트 키를 모두 입력하세요.');
      return;
    }
    await ClientAuthStore.instance().applyInput(extension: ext, clientKey: key);
    final st = await ClientAuthStore.instance()
        .markLocalVerified(reason: '외부망: OPS 접근 불가, SIP 자격으로 로컬 인증');
    if (!mounted) return;
    setState(() {
      _auth = st;
      _lastVerifyOffline = false;
      _verifyMsg = '오프라인 인증됨($ext): 주소록/설정 동기화는 제한됩니다.';
    });
    AppLogger.instance.evt('AUTH', 'verifyResult',
        state: 'localVerified', details: {'ext': ext});
  }

  Future<void> _applyQuality({
    required VideoQualityMode mode,
    required int frameRate,
  }) async {
    final next = VideoQualitySettings(mode, frameRate: frameRate);
    next.save();
    final media = context.read<MediaProvider>();
    final sip = context.read<SipProvider>();
    final ok = await media.getLocalMedia();
    var track = ok ? media.localStream?.getVideoTracks() : null;
    await sip.applyVideoQuality(
      videoTrack: (track != null && track.isNotEmpty) ? track.first : null,
    );
    if (!mounted) return;
    setState(() {
      _quality = next;
      _qualityMsg =
          '적용됨: ${next.label} · ${frameRate}fps${next.isAuto ? '' : ' · ${next.width}x${next.height}'}';
    });
  }

  Future<void> _resetAuth() async {
    final st = await ClientAuthStore.instance().resetAuth(reason: '사용자 재설정');
    if (!mounted) return;
    setState(() {
      _authExt.clear();
      _authKey.clear();
      _auth = st;
      _verifyMsg = '인증 정보를 초기화했습니다(키/인증 내선).';
    });
  }

  Future<_VerifyResult> _verifyAgainstServer(
      String base, String ext, String key) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      // DEV self-signed 허용
      client.badCertificateCallback = (cert, host, port) => true;
      final req = await client
          .getUrl(Uri.parse('$base/api/client/contacts'))
          .timeout(const Duration(seconds: 5));
      req.headers.add('X-Client-Key', key);
      req.headers.add('X-Client-Extension', ext);
      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200) {
        try {
          final j = jsonDecode(body) as Map<String, dynamic>;
          if (j['ok'] == true) return _VerifyResult(true, 200, 'ok');
        } catch (_) {}
        return _VerifyResult(true, 200, 'ok');
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return _VerifyResult(false, res.statusCode, '인증 실패(키/내선 확인 필요)');
      }
      return _VerifyResult(
          false, res.statusCode, '서버 응답 오류(${res.statusCode})');
    } catch (e) {
      return _VerifyResult(false, -1, '서버 연결 실패');
    } finally {
      client.close(force: true);
    }
  }

  void _postAuthFailLog(
      {required String ext,
      required int failCount,
      required int status,
      required bool reset}) {
    // best-effort: client-logs로 관리자 인지(민감값 제외)
    () async {
      try {
        final cfg = ServerConfigService.instance.current;
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3);
        client.badCertificateCallback = (cert, host, port) => true;
        final req = await client
            .postUrl(Uri.parse(cfg.clientLogUrl))
            .timeout(const Duration(seconds: 3));
        req.headers.contentType = ContentType.json;
        req.headers.add(
            'X-Client-Key',
            cfg.clientKey.isNotEmpty
                ? cfg.clientKey
                : AppConstants.opsClientKey);
        if (ext.isNotEmpty) req.headers.add('X-Client-Extension', ext);
        req.write(jsonEncode({
          'event': 'auth_verify_failed',
          'extension': ext,
          'failCount': failCount,
          'status': status,
          'reset': reset,
          'autoRevoked': false,
          'ts': DateTime.now().toUtc().toIso8601String(),
        }));
        await req.close();
      } catch (_) {}
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final verified = _auth.isVerified;
    final statusColor = _auth.isOfflineVerified
        ? Colors.orange
        : (verified
            ? Colors.green
            : (_auth.failCount > 0 ? Colors.orange : Colors.grey));
    final statusText = _auth.isOfflineVerified
        ? '오프라인 인증됨 (${_auth.authExtension})'
        : (verified
            ? '인증됨 (${_auth.authExtension})'
            : (_auth.failCount >= ClientAuthState.maxFailCount
            ? '미인증 · 10회 오류 초기화됨(재인증 필요)'
            : (_auth.failCount > 0 ? '미인증 (실패 ${_auth.failCount}/10)' : '미인증')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(verified ? Icons.verified_user : Icons.gpp_maybe,
                          color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(statusText,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authExt,
                      decoration: const InputDecoration(
                          labelText: '인증 내선',
                          hintText: '예: 1102',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _authKey,
                      decoration: const InputDecoration(
                        labelText: 'OPS 클라이언트 키(수동 입력)',
                        hintText: '엔터로 서버 검증',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verifying ? null : _verifyAuth(),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _verifying ? null : _verifyAuth,
                          icon: _verifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.verified),
                          label: const Text('검증(Enter)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: _resetAuth, child: const Text('인증 초기화')),
                    ]),
                    if ((_lastVerifyOffline ||
                            _domain.text.trim().contains('synology.me')) &&
                        !verified) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _verifyOffline,
                        icon: const Icon(Icons.cloud_off),
                        label: const Text('오프라인 인증 (외부망 · 주소록 제한)'),
                      ),
                    ],
                    if (_verifyMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(_verifyMsg!,
                          style: TextStyle(
                              color: _verifyMsg!.contains('성공') ||
                                      _verifyMsg!.contains('인증됨')
                                  ? Colors.green
                                  : Colors.redAccent)),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                        '※ Ops 클라이언트 키는 연락처/설정 동기화용이며 SIP 비밀번호와 별개입니다. 10회 실패 시 키/인증내선만 로컬 초기화됩니다(서버 자동 폐기 없음).',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('연결 설정 (${_profile.label})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ConnectionProfile>(
                      initialValue: _profile,
                      decoration: const InputDecoration(
                        labelText: '연결 프로필',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in ConnectionProfile.values)
                          DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ),
                      ],
                      onChanged: (p) {
                        if (p != null && p != _profile) _switchProfile(p);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _domain,
                        decoration: const InputDecoration(
                            labelText: 'SIP 도메인/서버 IP',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _port,
                        decoration: const InputDecoration(
                            labelText: 'SIP 포트', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _ws,
                        decoration: const InputDecoration(
                            labelText: 'WebSocket (ws/wss)',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _ops,
                        decoration: const InputDecoration(
                            labelText: 'Ops 주소 (http/https)',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                        onPressed: _saving ? null : _saveConnection,
                        child: const Text('연결 설정 저장')),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _autoConfigure,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('서버에서 자동 설정'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.network_check, size: 18),
                      label: const Text('연결 테스트'),
                    ),
                    if (_testResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final r in _testResults)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      r.ok ? Icons.check_circle : Icons.error_outline,
                                      size: 14,
                                      color: r.ok ? Colors.green : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${r.label} — ${r.detail}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_autoMsg != null) ...[
                      const SizedBox(height: 6),
                      Text(_autoMsg!,
                          style: TextStyle(
                              fontSize: 12,
                              color: _autoMsg!.contains('실패') ||
                                      _autoMsg!.contains('없습니다')
                                  ? Colors.orange
                                  : Colors.green)),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                        '프로필별 설정을 저장하며, 자동 설정은 연결되는 서버에만 적용됩니다. '
                        'DEV·PRD는 내부 OPS, 외부망은 DDNS OPS를 먼저 시도합니다.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('로그 전송',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => showLogSendDialog(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('로그보내기'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '자동보내기(5분 주기)와 즉시보내기(1회)를 함께 사용할 수 있습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('영상 품질 (수동 테스트)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<VideoQualityMode>(
                    initialValue: _quality.mode,
                    decoration: const InputDecoration(
                      labelText: '해상도 모드',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in VideoQualityMode.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text(VideoQualitySettings(m).label),
                        ),
                    ],
                    onChanged: (m) => setState(() {
                      _quality = _quality.copyWith(mode: m ?? _quality.mode);
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _quality.frameRate,
                    decoration: const InputDecoration(
                      labelText: '프레임률',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 fps')),
                      DropdownMenuItem(value: 24, child: Text('24 fps')),
                      DropdownMenuItem(value: 30, child: Text('30 fps')),
                      DropdownMenuItem(value: 60, child: Text('60 fps')),
                    ],
                    onChanged: (v) => setState(() {
                      _quality = _quality.copyWith(frameRate: v ?? _quality.frameRate);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(_quality.detail,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _applyQuality(
                      mode: _quality.mode,
                      frameRate: _quality.frameRate,
                    ),
                    child: const Text('품질 적용'),
                  ),
                  if (_qualityMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(_qualityMsg!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.green)),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    '자동 모드는 WebRTC가 최적화하며, 수동 모드는 카메라를 다시 열고 통화 중 트랙을 교체합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyResult {
  _VerifyResult(this.ok, this.statusCode, this.message);
  final bool ok;
  final int statusCode;
  final String message;
}
