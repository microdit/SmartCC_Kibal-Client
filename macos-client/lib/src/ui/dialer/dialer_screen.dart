import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../sip/sip_client.dart';
import '../../utils/app_logger.dart';
import '../../utils/call_log_store.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/ops_directory.dart';
import '../../utils/server_config.dart';

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
  bool _refreshingServer = false;
  List<CallLogEntry> _callLogs = const [];
  bool _showCallLog = false;

  @override
  void initState() {
    super.initState();
    _targetController.clear();
    _targetController.addListener(_onTargetChanged);
    _loadDirectory();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    final logs = await CallLogStore.instance.load();
    if (!mounted) return;
    setState(() => _callLogs = logs);
  }

  void _onTargetChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDirectory({bool refreshServerConfig = false}) async {
    if (refreshServerConfig) {
      if (mounted) setState(() => _refreshingServer = true);
      await ServerConfigService.instance.refresh();
    }
    final dir = await OpsDirectory.fetch();
    if (!mounted) return;
    setState(() {
      _directory = dir;
      _directoryLoaded = true;
      _refreshingServer = false;
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

    // 수신 통화는 app.dart 전역 다이얼로그로 처리 (별도 /incoming 라우트 없음)

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '주소록으로',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            // 반응형: 좁은 화면(폰/폴드)과 넓은 화면(TV/모니터)에 따라
            // 여백·폰트·카드 폭을 조절한다.
            final compact = w < 420;
            final wide = w >= 900;
            final landscapeShort = h < 520; // 가로형/폴드 펼침 상태
            final padH = compact ? 8.0 : (wide ? 28.0 : 16.0);
            final keyFont = landscapeShort
                ? (compact ? 18.0 : 22.0)
                : (wide ? 30.0 : 24.0);
            final maxFieldWidth = wide ? 520.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 720 : w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 등록 상태 및 정보 (짧은 화면에서는 최소화)
                    if (!landscapeShort) _buildStatusSection(sipProvider),
                    const Divider(height: 1),

                    // 번호 입력 필드
                    SizedBox(
                      width: maxFieldWidth,
                      child: _buildInputField(sipProvider),
                    ),

                    // 다이얼 패드: 남은 공간을 차지하며 Call Log 확장에 비례해 줄어든다.
                    Expanded(
                      child: _buildDialPad(
                        horizontalPadding: padH,
                        fontSize: keyFont,
                        compact: compact,
                      ),
                    ),

                    // 통화 버튼
                    _buildCallButton(sipProvider),

                    // 통화 기록 확장/접기 토글
                    _buildCallLogToggle(),
                    if (_showCallLog)
                      SizedBox(
                        height: (h * (landscapeShort ? 0.38 : 0.32)).clamp(120.0, 320.0),
                        child: _buildCallHistory(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Indicator
  //--------------------------------------------------------------------------

  Widget _buildStatusIndicator(SipProvider sipProvider) {
    final connecting = sipProvider.isLoading ||
        (!sipProvider.isRegistered &&
            sipProvider.sipState == SipClientState.connecting);
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
    final connecting = sipProvider.isLoading ||
        (!sipProvider.isRegistered &&
            sipProvider.sipState == SipClientState.connecting);
    final avatar = (username != null && username.isNotEmpty)
        ? (username.length >= 4
            ? username.substring(username.length - 4)
            : username)
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
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: _refreshingServer
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  tooltip: '서버 설정·연락처·회의실 갱신',
                  onPressed: _refreshingServer
                      ? null
                      : () => _loadDirectory(refreshServerConfig: true),
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
        child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
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

  Widget _buildQuickDialButton(String number,
      {bool isConference = false, String? tooltip}) {
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
          if (isConference) const Icon(Icons.groups_outlined, size: 16),
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

  Widget _buildDialPad({
    required double horizontalPadding,
    required double fontSize,
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 주어진 높이 안에서 4행이 모두 들어가도록 childAspectRatio를 계산.
        const cols = 3;
        const rows = 4;
        const spacing = AppConstants.spacingSm;
        final cellW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final cellH = (constraints.maxHeight - spacing * (rows - 1)) / rows;
        final ratio = cellH > 0 ? (cellW / cellH) : 1.2;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: GridView.count(
            crossAxisCount: cols,
            childAspectRatio: ratio.clamp(0.8, 2.2),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildDialButton('1', fontSize: fontSize, compact: compact),
              _buildDialButton('2', letters: 'ABC', fontSize: fontSize, compact: compact),
              _buildDialButton('3', letters: 'DEF', fontSize: fontSize, compact: compact),
              _buildDialButton('4', letters: 'GHI', fontSize: fontSize, compact: compact),
              _buildDialButton('5', letters: 'JKL', fontSize: fontSize, compact: compact),
              _buildDialButton('6', letters: 'MNO', fontSize: fontSize, compact: compact),
              _buildDialButton('7', letters: 'PQRS', fontSize: fontSize, compact: compact),
              _buildDialButton('8', letters: 'TUV', fontSize: fontSize, compact: compact),
              _buildDialButton('9', letters: 'WXYZ', fontSize: fontSize, compact: compact),
              _buildDialButton('*', fontSize: fontSize, compact: compact),
              _buildDialButton('0', letters: '+', fontSize: fontSize, compact: compact),
              _buildDialButton('#', fontSize: fontSize, compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialButton(String number,
      {String? letters, required double fontSize, required bool compact}) {
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
        textStyle: TextStyle(
          fontSize: fontSize,
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
              style: TextStyle(
                fontSize: compact ? 8 : 10,
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
    AppLogger.instance.ui('DIALER', 'callPressed', params: {'target': target});

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
      await CallLogStore.instance.add(target);
      await _loadCallLogs();
      if (!mounted) return;
      if (AppConstants.isConferenceRoom(target)) {
        context.push('/conference', extra: target);
      } else {
        context.push('/call', extra: target);
      }
    } else {
      if (!mounted) return;
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
          label: const Text('통화',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인')),
        ],
      ),
    );
  }

  void _handleMenuAction(String value, SipProvider sipProvider) {
    switch (value) {
      case 'unregister':
        sipProvider.unregister();
        if (mounted) context.go('/');
        break;
      case 'settings':
        context.push('/settings');
        break;
    }
  }

  //--------------------------------------------------------------------------
  // Call Log (확장/접기 + 재다이얼)
  //--------------------------------------------------------------------------

  Widget _buildCallLogToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: InkWell(
        onTap: () => setState(() => _showCallLog = !_showCallLog),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                _showCallLog ? Icons.expand_more : Icons.expand_less,
                size: 18,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                '통화 기록 (${_callLogs.length})',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const Spacer(),
              if (_callLogs.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _showCallLog = !_showCallLog),
                  child: Text(_showCallLog ? '접기' : '보기',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHistory() {
    if (_callLogs.isEmpty) {
      return const Center(
          child: Text('통화 기록이 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 13)));
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _callLogs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final log = _callLogs[i];
        final time = '${log.at.hour.toString().padLeft(2, '0')}:'
            '${log.at.minute.toString().padLeft(2, '0')}';
        return ListTile(
          dense: true,
          leading: Icon(
            log.direction == 'incoming' ? Icons.call_received : Icons.call_made,
            size: 18,
            color: log.direction == 'incoming' ? Colors.blue : Colors.green,
          ),
          title: Text(log.number,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('$time · ${log.direction}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: const Icon(Icons.call, size: 18, color: Colors.green),
          onTap: () {
            // 재다이얼: 번호를 채우고 즉시 발신
            _targetController.text = log.number;
            _targetController.selection = TextSelection.fromPosition(
                TextPosition(offset: log.number.length));
            final sip = Provider.of<SipProvider>(context, listen: false);
            _handleCall(sip);
          },
        );
      },
    );
  }
}
