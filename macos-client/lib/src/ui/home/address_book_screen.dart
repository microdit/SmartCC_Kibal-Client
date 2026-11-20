import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/media_provider.dart';
import '../../providers/sip_provider.dart';
import '../../sip/sip_client.dart';
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
  bool _sipRegistering = false;
  String? _sipError;

  /// 네트워크 전환으로 끊어진 회의실/통화 번호 (재연결 후 자동 재입장용)
  String? _callTargetBeforeNetworkLoss;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sip = Provider.of<SipProvider>(context, listen: false);
      sip.addListener(_onSipChanged);
      // 재연결 성공 시 끊어졌던 통화를 자동 재입장
      sip.onReconnected = _onSipReconnected;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      final sip = Provider.of<SipProvider>(context, listen: false);
      sip.removeListener(_onSipChanged);
      sip.onReconnected = null;
    } catch (_) {}
    super.dispose();
  }

  /// SIP 등록이 복구되면 네트워크 전환으로 끊어졌던 회의실에 자동 재입장한다.
  void _onSipReconnected() {
    if (!mounted) return;
    final target = _callTargetBeforeNetworkLoss;
    if (target == null) return;
    _callTargetBeforeNetworkLoss = null;
    final sip = Provider.of<SipProvider>(context, listen: false);
    if (!sip.isRegistered || sip.isInCall) return;
    AppLogger.instance.ui('RECOVERY', 'rejoinAfterNetworkRestore', params: {'target': target});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('네트워크 복구 · $target 통화를 다시 연결합니다.')));
    context.push(AppConstants.isConferenceRoom(target) ? '/conference' : '/call',
        extra: target);
  }

  /// SIP 등록 해제 감지: 끊어진 통화 번호를 기억하고 Provider의 백오프
  /// 재연결에 맡긴다(직접 재시도하면 init 경합으로 오히려 실패).
  void _onSipChanged() {
    if (!mounted || !_auth.isVerified) return;
    final sip = Provider.of<SipProvider>(context, listen: false);

    // 네트워크 전환으로 RTP가 20초간 끊기면 SIP transport가 아직 connected여도
    // 강제 재등록(re-init)을 트리거해 복구 시간을 단축한다.
    if (sip.mediaStalled && sip.isInCall && !sip.isConnecting) {
      final target = sip.currentCallTarget;
      if (target != null && target.isNotEmpty &&
          _callTargetBeforeNetworkLoss == null) {
        _callTargetBeforeNetworkLoss = target;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('네트워크가 끊어졌습니다. 전화를 다시 연결합니다…')));
      }
      AppLogger.instance.w('Media stall recovery: force SIP re-init');
      sip.connect();
      return;
    }

    if (sip.isRegistered) {
      if (_sipError != null) setState(() => _sipError = null);
      return;
    }
    // 통화 중 네트워크가 끊기면 재연결 후 재입장할 번호를 보관
    final target = sip.currentCallTarget;
    if (target != null && target.isNotEmpty &&
        _callTargetBeforeNetworkLoss == null) {
      _callTargetBeforeNetworkLoss = target;
      AppLogger.instance.w('Network loss during call → remember target $target for recovery');
    }
    if (sip.sipState == SipClientState.disconnected ||
        sip.sipState == SipClientState.error ||
        sip.sipState == SipClientState.unregistered) {
      setState(() {
        _sipError = '네트워크 변경으로 전화연결이 끊어졌습니다. 복구를 시도 중입니다…';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: true);
      _autoRegisterSip(notify: false);
    }
  }

  Future<void> _bootstrap() async {
    _auth = await ClientAuthStore.instance().load();
    await _refresh();
    if (mounted) setState(() => _loading = false);
    await _autoRegisterSip(notify: false);
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
    if (auth.isOfflineVerified) {
      // 오프라인 인증이라도 OPS가 부분적으로 도달 가능하면 주소록을 시도한다.
      // (SIP 비밀번호 동기화에 필요; 실패 시 빈 목록 + 안내 메시지)
      final dir = await OpsDirectory.fetch();
      if (!mounted) return;
      setState(() {
        _directory = dir;
        _lastSync = DateTime.now();
        _syncError = (dir.contacts.isEmpty && dir.rooms.isEmpty)
            ? '오프라인 인증 상태입니다. 주소록 동기화 실패(네트워크/OPS 확인). 다이얼패드/수신은 가능합니다.'
            : '오프라인 인증 상태입니다. 주소록은 부분 동기화되었습니다.';
      });
      AppLogger.instance.i(
          'AddressBook (offline) synced contacts=${dir.contacts.length} rooms=${dir.rooms.length}');
      if (!mounted) return;
      setState(() => _syncing = false);
      return;
    }
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

  /// 앱 시작/재개 시 인증 내선으로 SIP 자동 등록을 유지한다.
  /// 실패하면 상태바와 스낵바로 알린다.
  Future<bool> _autoRegisterSip({bool notify = true}) async {
    final sip = Provider.of<SipProvider>(context, listen: false);
    if (sip.isRegistered) return true;
    if (!_auth.isVerified || _auth.authExtension.isEmpty) {
      if (notify && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('SIP 자동 등록: 인증 내선이 없습니다. 설정에서 인증하세요.')));
      }
      return false;
    }
    final ext = _auth.authExtension;
    OpsContact? bound;
    for (final c in _directory.contacts) {
      if (c.extension == ext) {
        bound = c;
        break;
      }
    }
    // 오프라인/주소록 미동기화 시 DEV 빠른 계정 매핑으로 폴백 (수동 테스트용)
    final password = (bound?.sipPassword != null && bound!.sipPassword!.isNotEmpty)
        ? bound.sipPassword!
        : AppConstants.devQuickAccounts[ext];
    if (password == null || password.isEmpty) {
      setState(() => _sipError = '$ext SIP 비밀번호를 동기화하지 못했습니다.');
      if (notify && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('SIP 자동 등록 실패: $ext 비밀번호 미동기화')));
      }
      AppLogger.instance.w('SIP auto-register failed: $ext password missing');
      return false;
    }
    setState(() {
      _sipRegistering = true;
      _sipError = null;
    });
    final cfgBase = ServerConfigService.instance.current;
    final sipConfig = SipConfig.webrtc(
      username: ext,
      password: password,
      domain: cfgBase.sipDomain,
      port: cfgBase.sipPort,
      displayName: (bound != null && bound.displayName.isNotEmpty) ? bound.displayName : ext,
      wsServer: cfgBase.wsServer,
      iceServers: AppConstants.iceServersFor(
        cfgBase.wsServer.isEmpty ? cfgBase.sipDomain : cfgBase.wsServer,
      ),
    );
    sip.updateConfig(sipConfig);
    AppLogger.instance.ui('ADDRESSBOOK', 'autoRegister', params: {'ext': ext});
    final ok = await sip.connect();
    if (mounted) {
      setState(() {
        _sipRegistering = false;
        _sipError = ok && sip.isRegistered ? null : 'SIP 등록 실패: ${sip.error ?? "등록되지 않음"}';
      });
    }
    AppLogger.instance.evt('ADDRESSBOOK', 'autoRegisterResult',
        state: (ok && sip.isRegistered) ? 'registered' : 'failed',
        details: {'ext': ext, 'error': sip.error});
    if (notify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((ok && sip.isRegistered)
              ? 'SIP 등록됨 · $ext'
              : 'SIP 등록 실패: ${sip.error ?? "재시도 필요"}\n아이콘을 눌러 다시 시도하세요.')));
    }
    return ok && sip.isRegistered;
  }

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
      iceServers: AppConstants.iceServersFor(
        cfgBase.wsServer.isEmpty ? cfgBase.sipDomain : cfgBase.wsServer,
      ),
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
      setState(() => _sipError = null);
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
          content: Text('전화연결 안되어 있음 — SIP 등록 후 이용하세요.')));
      return;
    }
    if (AppConstants.isConferenceRoom(target)) {
      context.push('/conference', extra: target);
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
    final sip = Provider.of<SipProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소록'),
        actions: [
          IconButton(
              tooltip: sip.isRegistered
                  ? 'SIP 연결됨 · 누르면 재등록'
                  : 'SIP 연결 안됨 · 누르면 등록 시도',
              icon: _sipRegistering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      sip.isRegistered ? Icons.phone_enabled : Icons.phone_disabled,
                      color: sip.isRegistered ? Colors.green : Colors.red),
              onPressed: _sipRegistering ? null : () => _autoRegisterSip()),
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
    final sipOk = verified && sip.isRegistered;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _sipError != null
          ? Colors.red.withValues(alpha: 0.09)
          : (verified
              ? Colors.green.withValues(alpha: 0.08)
              : Colors.orange.withValues(alpha: 0.08)),
      child: Row(children: [
        Icon(verified ? Icons.verified_user : Icons.lock_outline,
            size: 18,
            color: _sipError != null
                ? Colors.red
                : (verified ? Colors.green : Colors.orange)),
        const SizedBox(width: 8),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sipError ??
                        (verified
                            ? '인증됨 · ${_auth.authExtension} · SIP ${sip.isRegistered ? "연결됨(리스닝)" : "연결 안됨"}${_lastSync != null ? " · 동기화 ${TimeOfDay.fromDateTime(_lastSync!).format(context)}" : ""}'
                            : '미인증: 주소록/일반통화는 인증 후 사용 (설정에서 키 검증)'),
                    style: TextStyle(
                        fontSize: 12,
                        color: _sipError != null ? Colors.red[700] : null),
                  ),
                  if (_sipError != null)
                    const Text('상단 전화 아이콘을 눌러 다시 등록하세요.',
                        style: TextStyle(fontSize: 11, color: Colors.red)),
                ])),
        if (verified)
          Icon(sipOk ? Icons.phone_enabled : Icons.phone_disabled,
              size: 16, color: sipOk ? Colors.green : Colors.red),
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
                      content: Text('전화연결 안되어 있음 — SIP 등록 후 회의실에 입장하세요.')));
                  return;
                }
                context.push('/conference', extra: r.room);
              },
            ),
        ]));
  }
}
