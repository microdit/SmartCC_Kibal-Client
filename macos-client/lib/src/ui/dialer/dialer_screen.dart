import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// 다이얼러 화면
/// 
/// 전화번호를 입력하고 통화를 시작하는 화면입니다.
/// 1:1 영상통화, 회의실 참가 기능을 제공합니다.
class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  // 전화번호 입력 컨트롤러
  final _targetController = TextEditingController();
  
  // 전화번호 포커스 노드
  final _targetFocus = FocusNode();
  
  // Dahilah_generator

  @override
  void initState() {
    super.initState();
    _targetFocus.addListener(() {
      if (!_targetFocus.hasFocus) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    _targetFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = Provider.of<SipProvider>(context);
    final mediaProvider = Provider.of<MediaProvider>(context);
    
    // SIP 등록되지 않은 경우 로그인 화면으로 리디렉션
    if (!sipProvider.isRegistered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, sipProvider),
      body: SafeArea(
        child: Column(
          children: [
            // 상태 바
            _buildStatusBar(sipProvider, mediaProvider),
            
            // 입력 필드
            _buildInputField(sipProvider),
            
            // 다이얼 패드
            _buildDialPad(),
            
            // 기존 통화 기록 (미구현)
            // _buildCallHistory(),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // App Bar
  //--------------------------------------------------------------------------
  
  PreferredSizeWidget _buildAppBar(BuildContext context, SipProvider sipProvider) {
    return AppBar(
      title: const Text('다이얼러'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _showSettingsDialog(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_outlined),
          onSelected: (value) => _handleMenuSelected(value, context),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout_outlined),
                title: Text('등록 해제'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'toggle_camera',
              child: ListTile(
                leading: Icon(Icons.camera_front_outlined),
                title: Text('카메라 전환'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: sipProvider.isInCall,
              child: const ListTile(
                leading: Icon(Icons.call_end_outlined),
                title: Text('통화 종료'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Status Bar
  //--------------------------------------------------------------------------
  
  Widget _buildStatusBar(SipProvider sipProvider, MediaProvider mediaProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                sipProvider.getRegistrationStatusText(),
                style: TextStyle(
                  color: _getStatusColor(sipProvider),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (mediaProvider.hasLocalStream)
                Row(
                  children: [
                    Icon(
                      mediaProvider.isVideoMuted 
                          ? Icons.videocam_off_outlined 
                          : Icons.videocam_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Icon(
                      mediaProvider.isAudioMuted 
                          ? Icons.mic_off_outlined 
                          : Icons.mic_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
            ],
          ),
          if (sipProvider.isInCall)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingXs),
              child: Row(
                children: [
                  const Icon(Icons.call_outlined, size: 14, color: Colors.green),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text(
                    sipProvider.getCallStatusText(),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
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
              hintText: '1002 또는 6000 (회의실)',
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
            onChanged: (_) {
              setState(() {});
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleCall(sipProvider),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          
          // Quick dial buttons
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickDialButton('1001'),
              _buildQuickDialButton('1002'),
              _buildQuickDialButton('1003'),
              _buildQuickDialButton('1004'),
              _buildQuickDialButton('6000', isConference: true),
            ],
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Quick Dial Button
  //--------------------------------------------------------------------------
  
  Widget _buildQuickDialButton(String number, {bool isConference = false}) {
    return OutlinedButton(
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
          const SizedBox(width: AppConstants.spacingXs),
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
            // Row 1
            _buildDialButton('1'),
            _buildDialButton('2', letters: 'ABC'),
            _buildDialButton('3', letters: 'DEF'),
            
            // Row 2
            _buildDialButton('4', letters: 'GHI'),
            _buildDialButton('5', letters: 'JKL'),
            _buildDialButton('6', letters: 'MNO'),
            
            // Row 3
            _buildDialButton('7', letters: 'PQRS'),
            _buildDialButton('8', letters: 'TUV'),
            _buildDialButton('9', letters: 'WXYZ'),
            
            // Row 4
            _buildDialButton('*'),
            _buildDialButton('0', letters: '+'),
            _buildDialButton('#'),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Dial Button
  //--------------------------------------------------------------------------
  
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

  //--------------------------------------------------------------------------
  // Call History (Placeholder)
  //--------------------------------------------------------------------------
  
  /*
  Widget _buildCallHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
          child: Text(
            '최근 통화',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        // 통화 기록 목록 (미구현)
      ],
    );
  }
  */

  //--------------------------------------------------------------------------
  // Dial Input Handler
  //--------------------------------------------------------------------------
  
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

  //--------------------------------------------------------------------------
  // Backspace Handler
  //--------------------------------------------------------------------------
  
  void _handleBackspace() {
    final current = _targetController.text;
    if (current.isNotEmpty) {
      _targetController.text = current.substring(0, current.length - 1);
      _targetController.selection = TextSelection.fromPosition(
        TextPosition(offset: _targetController.text.length),
      );
    }
  }

  //--------------------------------------------------------------------------
  // Quick Dial
  //--------------------------------------------------------------------------
  
  void _quickDial(String number) {
    _targetController.text = number;
    _targetController.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetController.text.length),
    );
    _targetFocus.requestFocus();
  }

  //--------------------------------------------------------------------------
  // Call Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleCall(SipProvider sipProvider) async {
    final target = _targetController.text.trim();
    
    if (target.isEmpty) {
      _showErrorDialog(context, '대상 번호를 입력하세요');
      return;
    }
    
    if (!Formatters.isValidSipUsername(target)) {
      _showErrorDialog(context, '유효한 번호가 아닙니다');
      return;
    }
    
    // 로컬 미디어 확보 후 통화 시작
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    if (!mediaProvider.hasLocalStream) {
      await mediaProvider.getLocalMedia();
    }

    final success = await sipProvider.call(
      target,
      mediaStream: mediaProvider.localStream,
    );
    
    if (!mounted) return;

    if (success) {
      // 통화 화면으로 이동
      context.push('/call', extra: target);
    } else {
      _showErrorDialog(context, '통화 시작에 실패했습니다: ${sipProvider.error}');
    }
  }

  //--------------------------------------------------------------------------
  // Settings Dialog
  //--------------------------------------------------------------------------
  
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라 전환'),
              trailing: const Icon(Icons.chevron_right_outlined),
              onTap: () => _handleCameraToggle(context),
            ),
            ListTile(
              leading: const Icon(Icons.mic_outlined),
              title: const Text('마이크 뮤트'),
              trailing: const Icon(Icons.chevron_right_outlined),
              onTap: () => _handleAudioToggle(context),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('비디오 뮤트'),
              trailing: const Icon(Icons.chevron_right_outlined),
              onTap: () => _handleVideoToggle(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Camera Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleCameraToggle(BuildContext context) async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    await mediaProvider.toggleCamera();
    if (context.mounted) Navigator.of(context).pop();
  }

  //--------------------------------------------------------------------------
  // Audio Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleAudioToggle(BuildContext context) async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    await mediaProvider.toggleAudio();
    if (context.mounted) Navigator.of(context).pop();
  }

  //--------------------------------------------------------------------------
  // Video Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleVideoToggle(BuildContext context) async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    await mediaProvider.toggleVideo();
    if (context.mounted) Navigator.of(context).pop();
  }

  //--------------------------------------------------------------------------
  // Menu Selected Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleMenuSelected(String value, BuildContext context) async {
    switch (value) {
      case 'logout':
        final sipProvider = Provider.of<SipProvider>(context, listen: false);
        final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
        
        await mediaProvider.releaseLocalMedia();
        await sipProvider.disconnect();
        sipProvider.clearConfig();
        
        if (context.mounted) {
          context.go('/');
        }
        break;
      case 'toggle_camera':
        if (context.mounted) {
          await _handleCameraToggle(context);
        }
        break;
    }
  }

  //--------------------------------------------------------------------------
  // Error Dialog
  //--------------------------------------------------------------------------
  
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
