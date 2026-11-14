import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../sip/sip_client.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/ops_directory.dart';

/// 다이얼러 화면
/// 
/// SIP 등록 후 통화할 상대방 번호를 입력하는 화면입니다.
/// 숫자 키패드를 사용하여 대상 번호를 입력하고 통화를 시작합니다.
class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  // 입력 컨트롤러
  final _targetController = TextEditingController();
  final _targetFocus = FocusNode();
  OpsDirectory _directory = const OpsDirectory();
  bool _directoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _targetController.clear();
    _targetController.addListener(_onTargetChanged);
    _loadDirectory();
  }

  void _onTargetChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDirectory() async {
    final dir = await OpsDirectory.fetch();
    if (!mounted) return;
    setState(() {
      _directory = dir;
      _directoryLoaded = true;
    });
  }

  @override
  void dispose() {
    _targetController.removeListener(_onTargetChanged);
    _targetController.dispose();
    _targetFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = Provider.of<SipProvider>(context);
    
    // 수신 통화 상태 확인
    if (sipProvider.hasIncomingCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/incoming');
      });
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Kibal'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // SIP 상태 표시
          _buildStatusIndicator(sipProvider),
          
          // 설정 메뉴
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, sipProvider),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'unregister',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: AppConstants.spacingSm),
                    Text('등록 해제'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: AppConstants.spacingSm),
                    Text('설정'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 등록 상태 및 정보
            _buildStatusSection(sipProvider),
            
            // 구분선
            const Divider(height: 1),
            
            // 번호 입력 필드
            _buildInputField(sipProvider),
            
            // 다이얼 패드
            _buildDialPad(),
            
            // 통화 버튼
            _buildCallButton(sipProvider),
            
            // 통화 기록 (선택 사항 - 현재 미구현)
            // _buildCallHistory(),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Indicator
  //--------------------------------------------------------------------------
  
  Widget _buildStatusIndicator(SipProvider sipProvider) {
    final connecting = sipProvider.isLoading || (!sipProvider.isRegistered && sipProvider.sipState == SipClientState.connecting);
    return Container(
      margin: const EdgeInsets.only(right: AppConstants.spacingMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(sipProvider),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            sipProvider.isRegistered ? '등록됨' : (connecting ? '연결 중' : '미등록'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Section
  //--------------------------------------------------------------------------
  
  Widget _buildStatusSection(SipProvider sipProvider) {
    final username = sipProvider.config?.username;
    final display = sipProvider.config?.displayName;
    final connecting = sipProvider.isLoading || (!sipProvider.isRegistered && sipProvider.sipState == SipClientState.connecting);
    final avatar = (username != null && username.isNotEmpty)
        ? (username.length >= 4 ? username.substring(username.length - 4) : username)
        : '--';
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      color: Colors.grey[50],
      child: Row(
        children: [
          // 아바타
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue,
            child: Text(
              avatar,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username != null
                      ? '$username${(display != null && display.isNotEmpty) ? ' ($display)' : ''}'
                      : '등록되지 않음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  sipProvider.isRegistered
                      ? 'SIP 서버에 연결되었습니다'
                      : connecting
                          ? '서버에 연결 중...'
                          : '연결되지 않음',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
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
    } else {
      return Colors.grey;
    }
  }

  //--------------------------------------------------------------------------
  // Input Field
  //--------------------------------------------------------------------------
  
  Widget _buildInputField(SipProvider sipProvider) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        children: [
          TextFormField(
            controller: _targetController,
            focusNode: _targetFocus,
            decoration: InputDecoration(
              labelText: '대상 번호',
              hintText: '내선번호 또는 회의실 번호',
              prefixIcon: const Icon(Icons.dialpad_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: () => _handleBackspace(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _targetController.clear(),
                  ),
                ],
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            onChanged: (_) {},
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleCall(sipProvider),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Text(
                  '빠른 연결',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'OPS 목록 새로고침',
                  onPressed: _loadDirectory,
                ),
              ],
            ),
          ),
          _buildQuickDialWrap(),
        ],
      ),
    );
  }

  Widget _buildQuickDialWrap() {
    final contacts = _directory.contacts;
    final rooms = _directory.rooms;
    if (!_directoryLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final children = <Widget>[];
    if (contacts.isEmpty && rooms.isEmpty) {
      // OPS 미응답/미설정 시 최소 폴백
      for (final n in const ['1101', '1102', '1103']) {
        children.add(_buildQuickDialButton(n));
      }
      for (final n in const ['6000', '6100']) {
        children.add(_buildQuickDialButton(n, isConference: true));
      }
    } else {
      for (final c in contacts) {
        children.add(_buildQuickDialButton(
          c.extension,
          isConference: AppConstants.isConferenceRoom(c.extension),
          tooltip: c.displayName.isNotEmpty ? c.displayName : null,
        ));
      }
      for (final r in rooms) {
        children.add(_buildQuickDialButton(
          r.room,
          isConference: true,
          tooltip: r.name.isNotEmpty ? r.name : null,
        ));
      }
    }
    return Wrap(
      spacing: AppConstants.spacingSm,
      runSpacing: AppConstants.spacingSm,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  //--------------------------------------------------------------------------
  // Quick Dial Button
  //--------------------------------------------------------------------------
  
  Widget _buildQuickDialButton(String number, {bool isConference = false, String? tooltip}) {
    final btn = OutlinedButton(
      onPressed: () => _quickDial(number),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        side: BorderSide(color: Colors.grey[400]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConference)
            const Icon(Icons.groups_outlined, size: 16),
          if (isConference) const SizedBox(width: AppConstants.spacingXs),
          Text(
            number,
            style: TextStyle(
              fontSize: 14,
              color: isConference ? Colors.blue : Colors.black87,
            ),
          ),
        ],
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  //--------------------------------------------------------------------------
  // Dial Pad
  //--------------------------------------------------------------------------
  
  Widget _buildDialPad() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
        child: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.2,
          crossAxisSpacing: AppConstants.spacingSm,
          mainAxisSpacing: AppConstants.spacingSm,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildDialButton('1'),
            _buildDialButton('2', letters: 'ABC'),
            _buildDialButton('3', letters: 'DEF'),
            _buildDialButton('4', letters: 'GHI'),
            _buildDialButton('5', letters: 'JKL'),
            _buildDialButton('6', letters: 'MNO'),
            _buildDialButton('7', letters: 'PQRS'),
            _buildDialButton('8', letters: 'TUV'),
            _buildDialButton('9', letters: 'WXYZ'),
            _buildDialButton('*'),
            _buildDialButton('0', letters: '+'),
            _buildDialButton('#'),
          ],
        ),
      ),
    );
  }

  Widget _buildDialButton(String number, {String? letters}) {
    return ElevatedButton(
      onPressed: () => _handleDialInput(number),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(number),
          if (letters != null)
            Text(
              letters,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  void _handleDialInput(String input) {
    if (input == '<') {
      _handleBackspace();
    } else {
      final current = _targetController.text;
      if (current.length < 10) {
        _targetController.text = current + input;
        _targetController.selection = TextSelection.fromPosition(
          TextPosition(offset: _targetController.text.length),
        );
      }
    }
  }

  void _handleBackspace() {
    final current = _targetController.text;
    if (current.isNotEmpty) {
      _targetController.text = current.substring(0, current.length - 1);
      _targetController.selection = TextSelection.fromPosition(
        TextPosition(offset: _targetController.text.length),
      );
    }
  }

  void _quickDial(String number) {
    _targetController.text = number;
    _targetController.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetController.text.length),
    );
    _targetFocus.requestFocus();
  }

  Future<void> _handleCall(SipProvider sipProvider) async {
    final target = _targetController.text.trim();
    AppLogger.instance.ui('DIALER', 'callPressed',
        params: {'target': target});

    if (target.isEmpty) {
      _showErrorDialog(context, '대상 번호를 입력하세요');
      return;
    }
    
    if (!Formatters.isValidSipUsername(target)) {
      _showErrorDialog(context, '유효한 번호가 아닙니다');
      return;
    }
    
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    if (!mediaProvider.hasLocalStream) {
      await mediaProvider.getLocalMedia();
    }

    final success = await sipProvider.call(
      target,
      mediaStream: mediaProvider.localStream,
    );
    
    if (!mounted) return;

    AppLogger.instance.evt('DIALER', 'callResult',
        state: success ? 'pushed' : 'failed',
        details: {'target': target, 'error': sipProvider.error});

    if (success) {
      if (AppConstants.isConferenceRoom(target)) {
        context.push('/conference');
      } else {
        context.push('/call');
      }
    } else {
      _showErrorDialog(context, sipProvider.error ?? '통화 연결에 실패했습니다');
    }
  }

  Widget _buildCallButton(SipProvider sipProvider) {
    final hasTarget = _targetController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: hasTarget ? () => _handleCall(sipProvider) : null,
          icon: const Icon(Icons.call),
          label: const Text('통화', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('확인')),
        ],
      ),
    );
  }

  void _handleMenuAction(String value, SipProvider sipProvider) {
    switch (value) {
      case 'unregister':
        sipProvider.unregister();
        if (mounted) context.go('/login');
        break;
      case 'settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정 화면은 준비 중입니다')),
        );
        break;
    }
  }
}
