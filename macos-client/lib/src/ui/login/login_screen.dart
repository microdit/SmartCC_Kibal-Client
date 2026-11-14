import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../sip/sip_config.dart';
import '../../sip/sip_client.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/ops_directory.dart';
import '../../utils/server_config.dart';

/// 로그인/SIP 등록 화면
/// 
/// SIP 계정 정보를 입력하고, 서버에 등록하는 화면입니다.
/// 등록 성공 후 다이얼러 화면으로 이동합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 폼 키
  final _formKey = GlobalKey<FormState>();
  
  // 입력 필드 컨트롤러
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  // 포커스 노드
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _domainFocus = FocusNode();
  final _portFocus = FocusNode();
  
  // 전송 타입 선택 — sip_ua 특성상 WS만 유효 (D1: UDP/TCP 선택 시 5060 ws 폭주 방지)
  SipTransportType _transportType = SipTransportType.ws;
  
  // WebSocket 서버 URL
  final _wsServerController = TextEditingController();
  
  // 오토 컴플리트 확장 번호
  
  // 초기 로드 완료 여부
  bool _isInitialLoad = true;
  bool _refreshingConfig = false;
  String? _configStatus;
  List<OpsContact> _quickContacts = const [];
  bool _quickContactsLoaded = false;

  @override
  void initState() {
    super.initState();
    
    // 초기 값 설정
    _usernameController.text = '';
    _passwordController.text = '';
    // 저장된 서버 설정(마지막 OPS 갱신값) → 없으면 기본값
    final saved = ServerConfigService.instance.current;
    _domainController.text = saved.sipDomain;
    _portController.text = saved.sipPort.toString();
    _wsServerController.text = saved.wsServer;

    // 화면 진입 시 OPS에서 최신 서버 주소 자동 갱신(서버 IP 변경 대응)
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshServerConfig(auto: true));
    _loadQuickContacts();
    
    // 포커스 리스너
    _usernameFocus.addListener(() {
      if (_usernameFocus.hasFocus && _usernameController.text.isEmpty) {
        // 자동 완성 제안
        _showExtensionSuggestions();
      }
    });
  }

  Future<void> _loadQuickContacts() async {
    final dir = await OpsDirectory.fetch();
    if (!mounted) return;
    setState(() {
      _quickContacts = dir.contacts;
      _quickContactsLoaded = true;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    _portController.dispose();
    _displayNameController.dispose();
    _wsServerController.dispose();
    
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _domainFocus.dispose();
    _portFocus.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = Provider.of<SipProvider>(context);
    final mediaProvider = Provider.of<MediaProvider>(context);
    
    // 초기 로드 시 안내 메시지 표시
    if (_isInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isInitialLoad = false;
        _showWelcomeDialog(context);
      });
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: AppConstants.spacingXl),
                
                // SIP 설정 폼
                _buildSipSettingsForm(sipProvider),
                const SizedBox(height: AppConstants.spacingMd),
                
                // 전송 타입 선택
                _buildTransportTypeSelector(),
                const SizedBox(height: AppConstants.spacingMd),
                
                // WebSocket 설정 (WebRTC용)
                if (_transportType == SipTransportType.ws || 
                    _transportType == SipTransportType.wss)
                  _buildWebSocketSettings(),
                
                // 연결 상태 표시
                _buildConnectionStatus(sipProvider),
                const SizedBox(height: AppConstants.spacingLg),
                
                // actions
                _buildActionButtons(sipProvider, mediaProvider),
                const SizedBox(height: AppConstants.spacingMd),
                
                // Quick Connect 버튼
                _buildQuickConnectButtons(sipProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Header
  //--------------------------------------------------------------------------
  
  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(
          Icons.phone_enabled,
          size: 64,
          color: Color(AppConstants.primaryColor),
        ),
        SizedBox(height: AppConstants.spacingMd),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          'SIP 영상통화 클라이언트',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // SIP Settings Form
  //--------------------------------------------------------------------------
  
  Widget _buildSipSettingsForm(SipProvider sipProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 사용자 이름 (내선)
        TextFormField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          decoration: InputDecoration(
            labelText: '내선 번호',
            hintText: '1001, 1002, 1003, 1004',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _usernameController.clear(),
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (value) {
            if (Formatters.isNullOrEmpty(value)) {
              return '내선 번호를 입력하세요';
            }
            if (!Formatters.isValidSipUsername(value!)) {
              return '유효한 내선 번호가 아닙니다 (1-6자리 숫자)';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        
        // 비밀번호
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          decoration: InputDecoration(
            labelText: '비밀번호',
            hintText: 'SIP 비밀번호',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _passwordController.clear(),
            ),
          ),
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          validator: (value) {
            if (Formatters.isNullOrEmpty(value)) {
              return '비밀번호를 입력하세요';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_domainFocus),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        
        // 도메인
        TextFormField(
          controller: _domainController,
          focusNode: _domainFocus,
          decoration: InputDecoration(
            labelText: '서버 도메인',
            hintText: '192.168.11.2',
            prefixIcon: const Icon(Icons.dns_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _domainController.clear(),
            ),
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            if (Formatters.isNullOrEmpty(value)) {
              return '서버 도메인을 입력하세요';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_portFocus),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        
        // 포트
        TextFormField(
          controller: _portController,
          focusNode: _portFocus,
          decoration: InputDecoration(
            labelText: '포트',
            hintText: '5060 (UDP), 8088 (WebSocket)',
            prefixIcon: const Icon(Icons.settings_ethernet_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _portController.clear(),
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          validator: (value) {
            if (Formatters.isNullOrEmpty(value)) {
              return '포트를 입력하세요';
            }
            final port = int.tryParse(value!);
            if (port == null || !Formatters.isValidPort(port)) {
              return '유효한 포트를 입력하세요 (1-65535)';
            }
            return null;
          },
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        
        // 표시 이름 (Optional)
        TextFormField(
          controller: _displayNameController,
          decoration: InputDecoration(
            labelText: '표시 이름 (선택)',
            hintText: 'Kibal Mobile 1001',
            prefixIcon: const Icon(Icons.text_fields_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _displayNameController.clear(),
            ),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Transport Type Selector
  //--------------------------------------------------------------------------
  
  Widget _buildTransportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '전송 프로토콜',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        SegmentedButton<SipTransportType>(
          segments: const [
            ButtonSegment(
              value: SipTransportType.ws,
              label: Text('WebSocket'),
              icon: Icon(Icons.web_outlined, size: 16),
            ),
          ],
          selected: const <SipTransportType>{SipTransportType.ws},
          onSelectionChanged: (Set<SipTransportType> newSelection) {
            setState(() {
              // sip_ua는 WS(TCP-fallback)만 지원 — UDP/TCP 전용 등록은 불가
              _transportType = SipTransportType.ws;
            });
          },
        ),
        const Text(
          'macOS/Web 클라이언트는 WebSocket(ws)만 지원합니다 (UDP/TCP 미지원)',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // WebSocket Settings
  //--------------------------------------------------------------------------
  
  Widget _buildServerConfigBar() {
    final cfg = ServerConfigService.instance.current;
    return Row(
      children: [
        Expanded(
          child: Text(
            _configStatus ??
                '서버 설정: ${cfg.sipDomain} (${cfg.source == 'ops' ? 'OPS 갱신' : cfg.source == 'saved' ? '저장값' : '기본값'})',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: _refreshingConfig ? null : () => _refreshServerConfig(auto: false),
          icon: _refreshingConfig
              ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync, size: 18),
          label: const Text('서버 설정 갱신'),
        ),
      ],
    );
  }

  /// OPS(/api/client/config)에서 서버 주소(IP/WS/OPS)와 연락처·회의실 목록을 함께 갱신한다.
  Future<void> _refreshServerConfig({required bool auto}) async {
    if (_refreshingConfig) return;
    setState(() {
      _refreshingConfig = true;
      _configStatus = '서버 설정/연락처/회의실 확인 중…';
    });
    AppLogger.instance.ui('LOGIN', 'serverConfigRefresh', params: {'auto': auto});
    final before = ServerConfigService.instance.current;
    final cfg = await ServerConfigService.instance
        .refresh(hintDomain: _domainController.text.trim());
    if (!mounted) return;

    final configChanged = cfg != null &&
        (!cfg.sameAddressAs(before) ||
            _domainController.text.trim() != cfg.sipDomain ||
            _wsServerController.text.trim() != cfg.wsServer);
    if (cfg != null) {
      _domainController.text = cfg.sipDomain;
      _portController.text = cfg.sipPort.toString();
      _wsServerController.text = cfg.wsServer;
    }

    await _loadQuickContacts();
    if (!mounted) return;

    final configMsg = cfg == null
        ? '서버 설정 갱신 실패 — OPS 응답 없음(현재 입력값 사용)'
        : (configChanged ? '서버 주소 갱신됨: ${cfg.sipDomain}' : '서버 설정 최신: ${cfg.sipDomain}');
    setState(() {
      _refreshingConfig = false;
      _configStatus = '$configMsg · 연락처 ${_quickContacts.length}건 갱신';
    });

    if (!auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cfg == null
              ? '연락처/회의실 갱신 완료(서버 주소 응답 없음) · 연락처 ${_quickContacts.length}건'
              : '서버 설정·연락처·회의실 갱신: ${cfg.sipDomain} · 연락처 ${_quickContacts.length}건'),
        ),
      );
    }
  }

  Widget _buildWebSocketSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        _buildServerConfigBar(),
        const SizedBox(height: AppConstants.spacingSm),
        TextFormField(
          controller: _wsServerController,
          decoration: const InputDecoration(
            labelText: 'WebSocket 서버',
            hintText: 'ws://<서버IP>:8088/ws (서버 설정 갱신으로 자동 입력)',
            prefixIcon: Icon(Icons.web_asset_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Connection Status
  //--------------------------------------------------------------------------
  
  Widget _buildConnectionStatus(SipProvider sipProvider) {
    final status = sipProvider.getRegistrationStatusText();
    final color = _getStatusColor(sipProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(sipProvider),
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            '상태: $status',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (sipProvider.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Color
  //--------------------------------------------------------------------------
  
  Color _getStatusColor(SipProvider sipProvider) {
    if (sipProvider.isRegistered) {
      return Colors.green;
    } else if (sipProvider.sipState == SipClientState.error) {
      return Colors.red;
    } else if (sipProvider.isLoading) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  //--------------------------------------------------------------------------
  // Status Icon
  //--------------------------------------------------------------------------
  
  IconData _getStatusIcon(SipProvider sipProvider) {
    if (sipProvider.isRegistered) {
      return Icons.check_circle_outline;
    } else if (sipProvider.sipState == SipClientState.error) {
      return Icons.error_outline;
    } else if (sipProvider.isLoading) {
      return Icons.timer_outlined;
    } else {
      return Icons.radio_button_unchecked_outlined;
    }
  }

  //--------------------------------------------------------------------------
  // Action Buttons
  //--------------------------------------------------------------------------
  
  Widget _buildActionButtons(SipProvider sipProvider, MediaProvider mediaProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: sipProvider.isRegistered 
              ? _handleLogout 
              : _handleLogin,
          icon: Icon(
            sipProvider.isRegistered 
                ? Icons.logout_outlined 
                : Icons.login_outlined,
          ),
          label: Text(
            sipProvider.isRegistered ? '등록 해제' : 'SIP 등록',
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
            backgroundColor: sipProvider.isRegistered 
                ? Colors.red 
                : const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        
        // 카메라 미리보기 버튼 (등록 후 활성화)
        OutlinedButton.icon(
          onPressed: sipProvider.isRegistered 
              ? () => _navigateToDialer(context)
              : null,
          icon: const Icon(Icons.dialpad_outlined),
          label: const Text(
            '다이얼러 열기',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Quick Connect Buttons
  //--------------------------------------------------------------------------
  
  Widget _buildQuickConnectButtons(SipProvider sipProvider) {
    final items = <({String ext, String? label})>[];
    if (_quickContacts.isNotEmpty) {
      for (final c in _quickContacts) {
        items.add((ext: c.extension, label: c.displayName.isNotEmpty ? c.displayName : null));
      }
    } else {
      // OPS 미응답/미설정 시 DEV 폴백
      for (final ext in AppConstants.devQuickAccounts.keys) {
        items.add((ext: ext, label: null));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '빠른 연결',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const Spacer(),
            if (!_quickContactsLoaded)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'OPS 목록 새로고침',
                onPressed: _loadQuickContacts,
              ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: [
            for (final it in items)
              _buildQuickConnectButton(sipProvider, it.ext, label: it.label),
          ],
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Quick Connect Button
  //--------------------------------------------------------------------------
  
  Widget _buildQuickConnectButton(SipProvider sipProvider, String extension, {String? label}) {
    final btn = OutlinedButton(
      onPressed: () => _quickConnect(sipProvider, extension),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        side: BorderSide(color: Colors.grey[400]!),
      ),
      child: Text(
        extension,
        style: const TextStyle(fontSize: 14),
      ),
    );
    if (label != null && label.isNotEmpty) {
      return Tooltip(message: label, child: btn);
    }
    return btn;
  }

  //--------------------------------------------------------------------------
  // Welcome Dialog
  //--------------------------------------------------------------------------
  
  void _showWelcomeDialog(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kibal Mobile에 오신 것을 환영합니다'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asterisk 기반 SIP 영상통화 클라이언트입니다.'),
              SizedBox(height: AppConstants.spacingSm),
              Text('계정을 입력하고 SIP 등록을 완료하세요.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('시작하기'),
            ),
          ],
        ),
      );
    });
  }

  //--------------------------------------------------------------------------
  // Login Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final domain = _domainController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? AppConstants.defaultSipPort;
    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : null;

    AppLogger.instance.ui('LOGIN', 'loginPressed',
        params: {
          'username': username,
          'domain': domain,
          'port': port,
          'transport': _transportType.name,
          'wsServer': _wsServerController.text.trim(),
        });
    
    // SIP 설정 생성
    SipConfig config;
    if (_transportType == SipTransportType.ws || _transportType == SipTransportType.wss) {
      final wsServer = _wsServerController.text.trim();
      config = SipConfig.webrtc(
        username: username,
        password: password,
        domain: domain,
        port: port,
        displayName: displayName,
        wsServer: wsServer,
        iceServers: AppConstants.prdIceServers,
      );
    } else {
      config = SipConfig.udp(
        username: username,
        password: password,
        domain: domain,
        port: port,
        displayName: displayName,
        iceServers: AppConstants.prdIceServers,
      );
    }
    
    // Provider에 설정 저장
    Provider.of<SipProvider>(context, listen: false).updateConfig(config);
    
    // 연결 시도
    final sipProvider = Provider.of<SipProvider>(context, listen: false);
    final success = await sipProvider.connect();
    AppLogger.instance.evt('LOGIN', 'loginResult',
        state: success ? 'registered' : 'failed',
        details: {'username': username, 'error': sipProvider.error});

    if (!mounted) return;

    if (success && sipProvider.isRegistered) {
      // 미디어 초기화
      final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
      await mediaProvider.getLocalMedia();
    }
  }

  //--------------------------------------------------------------------------
  // Logout Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleLogout() async {
    AppLogger.instance.ui('LOGIN', 'logoutPressed');
    final sipProvider = Provider.of<SipProvider>(context, listen: false);
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    
    // 미디어 해제 (로그아웃 — 풀 포함 완전 정리)
    await mediaProvider.disposeAllMedia();
    
    // SIP 연결 해제
    await sipProvider.disconnect();
    
    // 설정 초기화
    sipProvider.clearConfig();
  }

  //--------------------------------------------------------------------------
  // Quick Connect
  //--------------------------------------------------------------------------
  
  Future<void> _quickConnect(SipProvider sipProvider, String extension) async {
    _usernameController.text = extension;
    // 알려진 DEV 계정만 암호 자동 입력, 그 외는 직접 입력
    _passwordController.text = AppConstants.devQuickAccounts[extension] ?? '';
    AppLogger.instance.ui('LOGIN', 'quickConnectFilled',
        params: {'extension': extension});
  }

  //--------------------------------------------------------------------------
  // Navigation
  //--------------------------------------------------------------------------
  
  void _navigateToDialer(BuildContext context) {
    context.push('/dialer');
  }

  //--------------------------------------------------------------------------
  // Extension Suggestions
  //--------------------------------------------------------------------------
  
  void _showExtensionSuggestions() {
    // Future: show autocomplete popup
  }
}
