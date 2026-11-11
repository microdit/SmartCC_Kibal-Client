import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';

/// ConfBridge 회의실 화면
///
/// 회의실 번호(기본 6000)로 참가하고, 로컬/원격(브리지 믹스) 영상을 표시합니다.
class ConferenceView extends StatefulWidget {
  const ConferenceView({super.key, this.autoClose = false});

  /// 다이얼러에서 회의실 번호로 push된 화면이면 true → 통화 종료 시 자동 닫힘.
  /// (회의 탭에 상주하는 인스턴스는 false)
  final bool autoClose;

  @override
  State<ConferenceView> createState() => _ConferenceViewState();
}

class _ConferenceViewState extends State<ConferenceView> {
  final TextEditingController _roomController =
      TextEditingController(text: AppConstants.conferenceRoom);

  /// 선택된 원격 카드 인덱스(0..N-1). -1 = 내 영상 크게 보기.
  int _selectedRemote = 0;

  /// 다이얼러에서 회의실 번호로 진입(push)한 경우: 통화 종료 시 자동으로 닫는다.
  bool _wasInCall = false;

  @override
  void initState() {
    super.initState();
    context.read<SipProvider>().addListener(_handleSipChange);
  }

  @override
  void dispose() {
    context.read<SipProvider>().removeListener(_handleSipChange);
    _roomController.dispose();
    super.dispose();
  }

  void _handleSipChange() {
    if (!mounted) return;
    final sp = context.read<SipProvider>();
    if (sp.isInCall) {
      _wasInCall = true;
    } else if (_wasInCall) {
      _wasInCall = false;
      final nav = Navigator.of(context);
      if (widget.autoClose && nav.canPop()) {
        AppLogger.instance.ui('CONFERENCE', 'autoCloseOnCallEnd');
        nav.pop();
        return;
      }
    }

    final sipProvider = context.read<SipProvider>();
    final mediaProvider = context.read<MediaProvider>();

    for (final event in sipProvider.drainMediaEvents()) {
      mediaProvider.applySipMediaEvent(event, fallbackSession: 'conference');
    }
  }

  Future<void> _join() async {
    final sipProvider = context.read<SipProvider>();
    final mediaProvider = context.read<MediaProvider>();
    final room = _roomController.text.trim();

    if (room.isEmpty) return;

    AppLogger.instance.ui('CONFERENCE', 'joinPressed',
        params: {'room': room, 'registered': sipProvider.isRegistered});

    if (!mediaProvider.hasLocalStream) {
      AppLogger.instance.d('CONFERENCE: 로컬 미디어 없음 → getLocalMedia() 선행');
      await mediaProvider.getLocalMedia();
    }

    await sipProvider.call(room, mediaStream: mediaProvider.localStream);
  }

  Future<void> _leave() async {
    final sipProvider = context.read<SipProvider>();
    final mediaProvider = context.read<MediaProvider>();

    AppLogger.instance.ui('CONFERENCE', 'leavePressed',
        params: {'room': sipProvider.currentCallTarget ?? '-'});

    await sipProvider.hangup();
    await mediaProvider.removeAllRemoteStreams();
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = context.watch<SipProvider>();
    final mediaProvider = context.watch<MediaProvider>();
    final inConference = sipProvider.isInCall;

    return Scaffold(
      appBar: AppBar(
        title: Text(inConference
            ? '회의실 ${sipProvider.currentCallTarget ?? ''}'
            : '회의실'),
        actions: [
          if (inConference)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: _leave,
            ),
        ],
      ),
      body: inConference
          ? _buildConferenceGrid(mediaProvider)
          : _buildJoinForm(sipProvider),
      bottomNavigationBar: inConference
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      mediaProvider.isAudioMuted ? Icons.mic_off : Icons.mic,
                      color: mediaProvider.isAudioMuted ? Colors.red : Colors.green,
                    ),
                    onPressed: () => mediaProvider.toggleAudio(),
                  ),
                  IconButton(
                    icon: Icon(
                      mediaProvider.isVideoMuted
                          ? Icons.videocam_off
                          : Icons.videocam,
                      color: mediaProvider.isVideoMuted ? Colors.red : Colors.green,
                    ),
                    onPressed: () => mediaProvider.toggleVideo(),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    onPressed: _leave,
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 18),
                    label: const Text('회의 종료'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildJoinForm(SipProvider sipProvider) {
    return Center(
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: '회의실 번호',
                hintText: '6000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sipProvider.isRegistered ? _join : null,
              icon: const Icon(Icons.login),
              label: Text(sipProvider.isRegistered ? '회의 참가' : 'SIP 미등록'),
            ),
            if (sipProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  sipProvider.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 다자간 레이아웃: 큰 화면(선택 참가자) + 참가자 카드 목록 + 내 영상 PIP.
  ///
  /// - 원격 참가자는 카드(실시간 썸네일)로 나열, 클릭 시 큰 화면에 표시
  /// - 내 영상은 우상단 PIP로 항상 표시(카드에서도 선택 가능)
  /// - 같은 렌더러 텍스처를 큰 화면/썸네일이 공유(Texture 다중 표시)
  Widget _buildConferenceGrid(MediaProvider mediaProvider) {
    final remoteStreams = mediaProvider.remoteStreams;
    final remotes = <_ConferenceTile>[
      for (var i = 0; i < remoteStreams.length; i++)
        _ConferenceTile(
          label: '원격 ${i + 1}',
          renderer: mediaProvider.getRemoteRenderer(i),
          stream: remoteStreams[i],
        ),
    ];
    final local = _ConferenceTile(
      label: '내 영상',
      renderer: mediaProvider.getLocalRenderer(),
      stream: mediaProvider.hasLocalVideo ? mediaProvider.localStream : null,
      mirror: true,
    );

    if (_selectedRemote >= remotes.length) {
      _selectedRemote = remotes.isEmpty ? 0 : remotes.length - 1;
    }
    final showLocalBig = _selectedRemote < 0 || remotes.isEmpty;
    final big = showLocalBig ? local : remotes[_selectedRemote];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: remotes.isEmpty && !showLocalBig
                      ? _waitingView()
                      : _buildVideoTile(
                          label: big.label,
                          renderer: big.renderer,
                          stream: big.stream,
                          mirror: big.mirror,
                        ),
                ),
                if (remotes.isEmpty)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 12,
                    child: Center(
                      child: Chip(
                        label: Text('원격 영상 수신 준비중',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                if (!showLocalBig)
                  Positioned(
                    right: 12,
                    top: 12,
                    width: 180,
                    height: 110,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRemote = -1),
                      child: _buildVideoTile(
                        label: local.label,
                        renderer: local.renderer,
                        stream: local.stream,
                        mirror: true,
                        compact: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 118,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < remotes.length; i++)
                  _participantCard(
                    tile: remotes[i],
                    selected: !showLocalBig && _selectedRemote == i,
                    onTap: () {
                      AppLogger.instance.ui('CONFERENCE', 'participantSelected',
                          params: {'index': i + 1});
                      setState(() => _selectedRemote = i);
                    },
                  ),
                _participantCard(
                  tile: local,
                  selected: showLocalBig,
                  onTap: () => setState(() => _selectedRemote = -1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('원격 영상 수신 준비중',
            style: TextStyle(color: Colors.white54)),
      ),
    );
  }

  Widget _participantCard({
    required _ConferenceTile tile,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.blueAccent : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: _buildVideoTile(
            label: tile.label,
            renderer: tile.renderer,
            stream: tile.stream,
            mirror: tile.mirror,
            compact: true,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTile({
    required String label,
    required RTCVideoRenderer? renderer,
    required MediaStream? stream,
    bool mirror = false,
    bool compact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (renderer != null && stream != null)
              Builder(builder: (context) {
                if (renderer.srcObject != stream) {
                  renderer.srcObject = stream;
                }
                return RTCVideoView(
                  renderer,
                  mirror: mirror,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                );
              })
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined,
                        color: Colors.white54),
                    const SizedBox(height: 8),
                    Text(
                      label == '내 영상' ? '카메라 없음' : '원격 영상 수신 준비중',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConferenceTile {
  const _ConferenceTile({
    required this.label,
    required this.renderer,
    required this.stream,
    this.mirror = false,
  });

  final String label;
  final RTCVideoRenderer? renderer;
  final MediaStream? stream;
  final bool mirror;
}
