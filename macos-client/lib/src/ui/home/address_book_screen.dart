import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/media_provider.dart';
import '../../providers/sip_provider.dart';
import '../../sip/sip_config.dart';
import '../../utils/app_logger.dart';
import '../../utils/client_auth_state.dart';
import '../../utils/constants.dart';
import '../../utils/ops_directory.dart';
import '../../utils/server_config.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen>
    with WidgetsBindingObserver {
  OpsDirectory _directory = const OpsDirectory();
  bool _loading = true;
  bool _syncing = false;
  String? _syncError;
  ClientAuthState _auth = ClientAuthState.empty();
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: true);
    }
  }

  Future<void> _bootstrap() async {
    _auth = await ClientAuthStore.instance().load();
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      if (!silent) _syncError = null;
    });
    final auth = await ClientAuthStore.instance().load();
    _auth = auth;
    await ServerConfigService.instance.refresh(
      hintDomain: ServerConfigService.instance.current.sipDomain,
      clientKey: auth.clientKey,
      extension: auth.authExtension,
    );
    if (auth.isVerified) {
      final dir = await OpsDirectory.fetch();
      if (!mounted) return;
      setState(() {
        _directory = dir;
        _lastSync = DateTime.now();
        _syncError = (dir.contacts.isEmpty && dir.rooms.isEmpty)
            ? '연락처를 가져오지 못했습니다(네트워크/인증 확인).'
            : null;
      });
      AppLogger.instance.i(
          'AddressBook synced contacts=${dir.contacts.length} rooms=${dir.rooms.length}');
    } else {
      if (!mounted) return;
      setState(() {
        _directory = const OpsDirectory();
        _syncError = '미인증 상태입니다. 설정에서 인증 내선·OPS 클라이언트 키를 검증하세요.';
      });
    }
    if (!mounted) return;
    setState(() => _syncing = false);
  }

  bool get _canCall => _auth.isVerified;

  Future<void> _quickConnect(OpsContact c) async {
    if (!_canCall) {
      _goSettings('일반 통화는 인증된 상태에서만 가능합니다.');
      return;
    }
    final password = c.sipPassword;
    if (password == null || password.isEmpty) {
      _goSettings('SIP 비밀번호를 동기화하지 못했습니다. 인증/동기화를 다시 확인하세요.');
      return;
    }
    final sip = Provider.of<SipProvider>(context, listen: false);
    final cfgBase = ServerConfigService.instance.current;
    final sipConfig = SipConfig.webrtc(
      username: c.extension,
      password: password,
      domain: cfgBase.sipDomain,
      port: cfgBase.sipPort,
      displayName: c.displayName.isNotEmpty ? c.displayName : c.extension,
      wsServer: cfgBase.wsServer,
      iceServers: AppConstants.prdIceServers,
    );
    sip.updateConfig(sipConfig);
    AppLogger.instance
        .ui('ADDRESSBOOK', 'quickConnect', params: {'ext': c.extension});
    final ok = await sip.connect();
    AppLogger.instance.evt('ADDRESSBOOK', 'quickConnectResult',
        state: ok ? 'registered' : 'failed',
        details: {'ext': c.extension, 'error': sip.error});
    if (!mounted) return;
    if (ok && sip.isRegistered) {
      final media = Provider.of<MediaProvider>(context, listen: false);
      await media.getLocalMedia();
      if (!mounted) return;
      context.push('/dialer');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sip.error ?? '연결 실패')));
    }
  }

  void _goSettings([String? msg]) {
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    context.push('/settings').then((_) => _refresh());
  }

  void _openTestCall() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('네트워크 점검(테스트 통화)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                    'DEV 진단용. 테스트 내선/회의실 및 미디어 자산(영상·녹음·녹화 재생)은 서버/인프라 구성 후 사용 가능합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.call),
                  title: const Text('테스트 1:1 (내선 7001)'),
                  subtitle: const Text('서버 테스트 클라이언트/에코 연결'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _dialTest('7001');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: const Text('테스트 회의실 (6700)'),
                  subtitle: const Text('지정 영상/녹음/녹화 재생 점검'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _dialTest('6700');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.perm_media),
                  title: const Text('미디어 장치 테스트'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/mediaTest');
                  },
                ),
              ]),
        ),
      ),
    );
  }

  void _dialTest(String target) {
    if (!Provider.of<SipProvider>(context, listen: false).isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('테스트 통화는 SIP 등록 후 사용하세요. 주소록에서 계정으로 연결하거나 설정에서 등록하세요.')));
      return;
    }
    if (AppConstants.isConferenceRoom(target)) {
      context.push('/conference');
    } else {
      context.push('/call', extra: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final verified = _auth.isVerified;
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소록'),
        actions: [
          IconButton(
              tooltip: '네트워크 점검(테스트)',
              icon: const Icon(Icons.network_check),
              onPressed: _openTestCall),
          IconButton(
              tooltip: '새로고침',
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              onPressed: _syncing ? null : () => _refresh()),
          IconButton(
              tooltip: '설정',
              icon:
                  Icon(Icons.settings, color: verified ? null : Colors.orange),
              onPressed: () => _goSettings()),
        ],
      ),
      body: Column(children: [
        _buildStatusBar(verified),
        if (_syncError != null)
          MaterialBanner(
            content: Text(_syncError!),
            leading: const Icon(Icons.info_outline),
            actions: [
              TextButton(
                  onPressed: () => _goSettings(), child: const Text('설정')),
              TextButton(
                  onPressed: () => _refresh(), child: const Text('다시 시도'))
            ],
          ),
        Expanded(child: _buildList(verified)),
      ]),
      floatingActionButton: verified
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/dialer'),
              icon: const Icon(Icons.dialpad),
              label: const Text('다이얼'))
          : null,
    );
  }

  Widget _buildStatusBar(bool verified) {
    final sip = Provider.of<SipProvider>(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: verified
          ? Colors.green.withValues(alpha: 0.08)
          : Colors.orange.withValues(alpha: 0.08),
      child: Row(children: [
        Icon(verified ? Icons.verified_user : Icons.lock_outline,
            size: 18, color: verified ? Colors.green : Colors.orange),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          verified
              ? '인증됨 · ${_auth.authExtension} · SIP ${sip.isRegistered ? "등록됨" : "미등록"}${_lastSync != null ? " · 동기화 ${TimeOfDay.fromDateTime(_lastSync!).format(context)}" : ""}'
              : '미인증: 주소록/일반통화는 인증 후 사용 (설정에서 키 검증)',
          style: const TextStyle(fontSize: 12),
        )),
      ]),
    );
  }

  Widget _buildList(bool verified) {
    if (!verified) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.contacts, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('주소록은 인증 후 서버에서 최신 정보를 받아옵니다.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => _goSettings(),
                    child: const Text('설정에서 인증하기')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: _openTestCall,
                    icon: const Icon(Icons.network_check),
                    label: const Text('네트워크 점검(테스트)')),
              ])));
    }
    final contacts = _directory.contacts;
    final rooms = _directory.rooms;
    if (contacts.isEmpty && rooms.isEmpty) {
      return Center(
          child: Text(
              _syncing ? '동기화 중...' : '표시할 연락처가 없습니다. 새로고침하거나 Ops 설정을 확인하세요.'));
    }
    return RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView(children: [
          if (contacts.isNotEmpty)
            const ListTile(
                title:
                    Text('연락처', style: TextStyle(fontWeight: FontWeight.w600))),
          for (final c in contacts)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c.label),
              subtitle: Text(c.sipPassword != null ? '즉시 연결 가능' : '비밀번호 미동기화'),
              trailing: FilledButton.tonal(
                  onPressed: () => _quickConnect(c), child: const Text('연결')),
              onTap: () => _quickConnect(c),
            ),
          if (rooms.isNotEmpty) const Divider(),
          if (rooms.isNotEmpty)
            const ListTile(
                title:
                    Text('회의실', style: TextStyle(fontWeight: FontWeight.w600))),
          for (final r in rooms)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.groups)),
              title: Text(r.name.isNotEmpty ? '${r.room} ${r.name}' : r.room),
              subtitle: Text(r.mode),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (!_canCall) {
                  _goSettings('인증 후 이용하세요.');
                  return;
                }
                final sip = Provider.of<SipProvider>(context, listen: false);
                if (!sip.isRegistered) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('먼저 연락처로 SIP 등록 후 회의실에 입장하세요.')));
                  return;
                }
                context.push('/conference');
              },
            ),
        ]));
  }
}
