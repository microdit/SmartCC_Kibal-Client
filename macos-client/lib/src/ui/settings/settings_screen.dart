import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_logger.dart';
import '../../utils/client_auth_state.dart';
import '../../utils/constants.dart';
import '../../utils/ops_directory.dart';
import '../../utils/server_config.dart';

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
  ClientAuthState _auth = ClientAuthState.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = ServerConfigService.instance.current;
    final auth = await ClientAuthStore.instance().load();
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

  Future<void> _saveConnection() async {
    setState(() => _saving = true);
    final cfg = ServerConfigService.instance.current.copyWith(
      sipDomain: _domain.text.trim(),
      sipPort: int.tryParse(_port.text.trim()) ?? AppConstants.defaultSipPort,
      wsServer: _ws.text.trim(),
      opsBaseUrl: _ops.text.trim(),
      source: 'saved',
    );
    ServerConfigService.instance
        .setCurrent(cfg); // ignore: invalid_use_of_visible_for_testing_member
    cfg.save();
    AppLogger.instance.ui('SETTINGS', 'connectionSaved', params: {
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
    final statusColor = verified
        ? Colors.green
        : (_auth.failCount > 0 ? Colors.orange : Colors.grey);
    final statusText = verified
        ? '인증됨 (${_auth.authExtension})'
        : (_auth.failCount >= ClientAuthState.maxFailCount
            ? '미인증 · 10회 오류 초기화됨(재인증 필요)'
            : (_auth.failCount > 0 ? '미인증 (실패 ${_auth.failCount}/10)' : '미인증'));

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
                    const Text('연결 설정 (DEV)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
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
                    const SizedBox(height: 4),
                    const Text(
                        '보안통신(HTTPS/WSS) 전환 시 서버 인증서·Asterisk WSS 구성이 필요합니다(DEV).',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
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
