import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// 통화 화면
/// 
/// 1:1 영상통화 또는 다자간 영상회의 화면입니다.
/// 로컬/원격 영상 표시, 통화 제어 기능을 제공합니다.
class CallScreen extends StatefulWidget {
  final String target;
  
  const CallScreen({super.key, required this.target});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // 통화 시작 시간
  DateTime? _callStartTime;
  
  // 통화 duration 타이머
  Timer? _callTimer;
  
  // 통화 duration
  Duration _callDuration = Duration.zero;
  
  // 통화가 한 번이라도 연결되었는지 여부
  bool _wasInCall = false;

  // 사용자가 직접 종료 중인지 여부
  bool _isClosing = false;

  // 종료 다이얼로그 중복/자동닫힘 방지 가드 (D5)
  bool _endedDialogShown = false;

  // dispose 시 안전하게 제거하기 위해 참조 저장
  late final SipProvider _sipProviderRef;

  @override
  void initState() {
    super.initState();

    // 통화 시작 시간 설정
    _callStartTime = DateTime.now();

    // 타이머 시작
    _startCallTimer();

    // 미디어 초기화
    _initMedia();

    // 상태 리스너 (참조 저장 후 등록 — dispose에서 안전 처리)
    _sipProviderRef = Provider.of<SipProvider>(context, listen: false);
    _sipProviderRef.addListener(_handleSipStateChange);
  }

  @override
  void dispose() {
    // 타이머 정지
    _stopCallTimer();

    // 리스너 제거 (deactivated 후 context 접근 방지)
    _sipProviderRef.removeListener(_handleSipStateChange);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = Provider.of<SipProvider>(context);
    final mediaProvider = Provider.of<MediaProvider>(context);
    
    return PopScope(
      // 뒤로 가기 방지 (통화 중에는 종료 버튼만 사용)
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => _toggleOrientationLock(),
            child: Stack(
              children: [
                // 비디오 영역
                _buildVideoArea(sipProvider, mediaProvider),
                
                // 통화 정보
                _buildCallInfo(sipProvider),
                
                // 컨트롤 패널
                _buildControlPanel(sipProvider, mediaProvider),
                
                //_status bar
                _buildStatusBar(sipProvider, mediaProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Video Area
  //--------------------------------------------------------------------------
  
  Widget _buildVideoArea(SipProvider sipProvider, MediaProvider mediaProvider) {
    // 로컬 PIP는 외부 Stack의 직계 Positioned로 두어야 합니다.
    // (Column 내부에 Positioned를 두면 ParentDataWidget 오류로 렌더링이 깨집니다.)
    return Positioned.fill(
      child: Stack(
        children: [
          // 원격 영상 (메인 화면)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildRemoteVideo(mediaProvider),
            ),
          ),
          // 로컬 영상 (PIP - Picture in Picture)
          if (mediaProvider.hasLocalVideo)
            Positioned(
              bottom: AppConstants.spacingLg + 100, // Control panel above
              right: AppConstants.spacingMd,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
                  child: _buildLocalVideo(mediaProvider),
                ),
              ),
            ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Remote Video
  //--------------------------------------------------------------------------
  
  Widget _buildRemoteVideo(MediaProvider mediaProvider) {
    final remoteStreams = mediaProvider.remoteStreams;
    
    if (remoteStreams.isEmpty) {
      return _buildPlaceholderVideo('원격 영상');
    }
    
    // 첫 번째 원격 스트림 사용
    final stream = remoteStreams.first;
    final renderer = mediaProvider.getRemoteRenderer(0);
    
    if (renderer != null) {
      renderer.srcObject = stream;
      return RTCVideoView(
        renderer,
        mirror: false,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    }
    
    return _buildPlaceholderVideo('원격 영상');
  }

  //--------------------------------------------------------------------------
  // Local Video
  //--------------------------------------------------------------------------
  
  Widget _buildLocalVideo(MediaProvider mediaProvider) {
    final stream = mediaProvider.localStream;
    final renderer = mediaProvider.getLocalRenderer();
    
    if (renderer != null && stream != null) {
      renderer.srcObject = stream;
      return RTCVideoView(
        renderer,
        mirror: mediaProvider.isFrontCamera,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    
    return _buildPlaceholderVideo('로컬 영상');
  }

  //--------------------------------------------------------------------------
  // Placeholder Video
  //--------------------------------------------------------------------------
  
  Widget _buildPlaceholderVideo(String label) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              '$label을 기다리는 중...',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Call Info
  //--------------------------------------------------------------------------
  
  Widget _buildCallInfo(SipProvider sipProvider) {
    return Positioned(
      top: AppConstants.spacingMd,
      left: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sipProvider.currentCallTarget ?? '상대방',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            // 연결 상태 명확화: Ring/Progress에서는 "연결 중", ACBEPTED 이후 "연결됨"
            (sipProvider.isCallEstablished
                ? '연결됨 · ${Formatters.formatCallDuration(_callDuration)}'
                : '연결 중…'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Control Panel
  //--------------------------------------------------------------------------
  
  Widget _buildControlPanel(SipProvider sipProvider, MediaProvider mediaProvider) {
    return Positioned(
      bottom: AppConstants.spacingMd,
      left: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 카메라 전환
            _buildControlButton(
              icon: Icons.camera_front_outlined,
              label: '전환',
              color: Colors.white70,
              onPressed: () => _handleCameraToggle(mediaProvider),
            ),
            
            // 음소거
            _buildControlButton(
              icon: mediaProvider.isAudioMuted 
                  ? Icons.mic_off_outlined 
                  : Icons.mic_outlined,
              label: mediaProvider.isAudioMuted ? '음소거 해제' : '음소거',
              color: mediaProvider.isAudioMuted ? Colors.red : Colors.white70,
              onPressed: () => _handleAudioToggle(mediaProvider),
            ),
            
            // 영상享年
            _buildControlButton(
              icon: mediaProvider.isVideoMuted 
                  ? Icons.videocam_off_outlined 
                  : Icons.videocam_outlined,
              label: mediaProvider.isVideoMuted ? '영상 켜기' : '영상 끄기',
              color: mediaProvider.isVideoMuted ? Colors.red : Colors.white70,
              onPressed: () => _handleVideoToggle(mediaProvider),
            ),
            
            // 스피커
            _buildControlButton(
              icon: Icons.volume_up_outlined,
              label: '스피커',
              color: Colors.white70,
              onPressed: () => _handleSpeakerToggle(),
            ),
            
            // 통화 종료
            _buildControlButton(
              icon: Icons.call_end_outlined,
              label: '종료',
              color: Colors.red,
              size: 64,
              onPressed: () => _handleHangup(sipProvider, mediaProvider),
            ),
          ],
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Control Button
  //--------------------------------------------------------------------------
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    double size = 56,
    VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: size / 2),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: color,
            padding: EdgeInsets.all(size / 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(size),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Status Bar
  //--------------------------------------------------------------------------
  
  Widget _buildStatusBar(SipProvider sipProvider, MediaProvider mediaProvider) {
    return Positioned(
      top: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 등록 상태
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
              vertical: AppConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              color: sipProvider.isRegistered 
                  ? Colors.green.withValues(alpha: 0.2) 
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sipProvider.isRegistered 
                      ? Icons.check_circle_outline 
                      : Icons.error_outline,
                  color: sipProvider.isRegistered ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Text(
                  sipProvider.isRegistered ? '등록됨' : '미등록',
                  style: TextStyle(
                    color: sipProvider.isRegistered ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          
          // 미디어 상태
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
              vertical: AppConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              color: mediaProvider.hasLocalStream 
                  ? Colors.blue.withValues(alpha: 0.2) 
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mediaProvider.hasLocalVideo 
                      ? Icons.videocam_outlined 
                      : Icons.videocam_off_outlined,
                  color: mediaProvider.hasLocalVideo ? Colors.blue : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Text(
                  mediaProvider.hasLocalStream ? '미디어 ON' : '미디어 OFF',
                  style: TextStyle(
                    color: mediaProvider.hasLocalStream ? Colors.blue : Colors.grey,
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
  // Timer Management
  //--------------------------------------------------------------------------
  
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_callStartTime != null) {
            _callDuration = DateTime.now().difference(_callStartTime!);
          }
        });
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  //--------------------------------------------------------------------------
  // Media Initialization
  //--------------------------------------------------------------------------
  
  Future<void> _initMedia() async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    if (!mediaProvider.hasLocalStream) {
      await mediaProvider.getLocalMedia();
    }
  }

  //--------------------------------------------------------------------------
  // Orientation Lock Toggle
  //--------------------------------------------------------------------------
  
  Future<void> _toggleOrientationLock() async {
    // Implement orientation lock toggle
  }

  //--------------------------------------------------------------------------
  // SIP State Change Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleSipStateChange() async {
    final sipProvider = Provider.of<SipProvider>(context, listen: false);
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);

    // SIP 엔진에서 전달된 원격 스트림을 렌더러에 연결
    for (final event in sipProvider.drainMediaEvents()) {
      if (event['action'] != 'stream') continue;

      final stream = event['stream'];
      final originator = event['originator'] as String? ?? '';
      if (stream is MediaStream && originator.contains('remote')) {
        mediaProvider.addRemoteStream(
          stream,
          event['sessionId'] as String? ?? 'remote',
        );
      }
    }

    if (sipProvider.isInCall) {
      _wasInCall = true;
      return;
    }

    // D5: 상대방/서버 종료 등 — 로컬 미디어·원격 스트림 정리는 1회만,
    // 종료 다이얼로그는 사용자가 확인할 때까지 유지 (자동 닫힘/중복 방지)
    if (_wasInCall && !_isClosing) {
      _wasInCall = false;
      AppLogger.instance.ui('CALL', 'remoteEndedDetected',
          params: {'target': sipProvider.currentCallTarget ?? '-'});
      if (_endedDialogShown) return;
      _endedDialogShown = true;
      await mediaProvider.releaseLocalMedia();
      await mediaProvider.removeAllRemoteStreams();
      if (mounted) {
        _showCallEndedDialog(sipProvider);
      }
    }
  }

  //--------------------------------------------------------------------------
  // Call Ended Dialog
  //--------------------------------------------------------------------------
  
  void _showCallEndedDialog(SipProvider sipProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('통화 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_end_outlined, size: 48, color: Colors.red),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              '통화가 종료되었습니다',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              '통화 시간: ${Formatters.formatCallDuration(_callDuration)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/dialer');
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Camera Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleCameraToggle(MediaProvider mediaProvider) async {
    AppLogger.instance.ui('CALL', 'cameraTogglePressed');
    await mediaProvider.toggleCamera();
    AppLogger.instance.evt('MEDIA', 'cameraToggled',
        state: 'front=${mediaProvider.isFrontCamera}');
  }

  //--------------------------------------------------------------------------
  // Audio Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleAudioToggle(MediaProvider mediaProvider) async {
    AppLogger.instance.ui('CALL', 'micTogglePressed');
    await mediaProvider.toggleAudio();
    AppLogger.instance.evt('MEDIA', 'micToggled',
        state: 'muted=${mediaProvider.isAudioMuted}');
  }

  //--------------------------------------------------------------------------
  // Video Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleVideoToggle(MediaProvider mediaProvider) async {
    AppLogger.instance.ui('CALL', 'videoTogglePressed');
    await mediaProvider.toggleVideo();
    AppLogger.instance.evt('MEDIA', 'videoMuteToggled',
        state: 'muted=${mediaProvider.isVideoMuted}');
  }

  //--------------------------------------------------------------------------
  // Speaker Toggle Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleSpeakerToggle() async {
    // Implement speaker toggle
  }

  //--------------------------------------------------------------------------
  // Hangup Handler
  //--------------------------------------------------------------------------
  
  Future<void> _handleHangup(SipProvider sipProvider, MediaProvider mediaProvider) async {
    _isClosing = true;
    AppLogger.instance.ui('CALL', 'hangupPressed', params: {'target': sipProvider.currentCallTarget});

    // 통화 종료
    await sipProvider.hangup();
    
    // 미디어 해제
    await mediaProvider.releaseLocalMedia();
    
    // 다이얼러 화면으로 이동
    if (mounted) {
      context.go('/dialer');
    }
  }
}
