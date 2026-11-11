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
  const ConferenceView({super.key});

  @override
  State<ConferenceView> createState() => _ConferenceViewState();
}

class _ConferenceViewState extends State<ConferenceView> {
  final TextEditingController _roomController =
      TextEditingController(text: AppConstants.conferenceRoom);

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

    final sipProvider = context.read<SipProvider>();
    final mediaProvider = context.read<MediaProvider>();

    for (final event in sipProvider.drainMediaEvents()) {
      if (event['action'] != 'stream') continue;

      final stream = event['stream'];
      final originator = event['originator'] as String? ?? '';
      if (stream is MediaStream && originator.contains('remote')) {
        mediaProvider.addRemoteStream(
          stream,
          event['sessionId'] as String? ?? 'conference',
        );
      }
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

  Widget _buildConferenceGrid(MediaProvider mediaProvider) {
    final remoteStreams = mediaProvider.remoteStreams;
    final tileCount = 1 + remoteStreams.length;

    return GridView.count(
      crossAxisCount: tileCount > 1 ? 2 : 1,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildVideoTile(
          label: '내 영상',
          renderer: mediaProvider.getLocalRenderer(),
          stream: mediaProvider.localStream,
          mirror: true,
        ),
        for (var i = 0; i < remoteStreams.length; i++)
          _buildVideoTile(
            label: '회의 영상 ${i + 1}',
            renderer: mediaProvider.getRemoteRenderer(i),
            stream: remoteStreams[i],
          ),
      ],
    );
  }

  Widget _buildVideoTile({
    required String label,
    required RTCVideoRenderer? renderer,
    required MediaStream? stream,
    bool mirror = false,
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
              const Center(
                child: Icon(Icons.videocam_off_outlined, color: Colors.white54),
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
