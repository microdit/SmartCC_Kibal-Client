import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/sip_provider.dart';
import '../../providers/media_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/conference_participants.dart';
import '../../utils/constants.dart';
import '../../utils/window_fullscreen.dart';
import '../common/fullscreen_stage.dart';

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

  /// 큰 화면 영상 전체 화면 모드
  bool _fullscreen = false;
  String _bigLabel = '-';

  void _setFullscreen(bool v) {
    if (_fullscreen == v) return;
    setState(() => _fullscreen = v);
    WindowFullscreen.set(v, screen: 'conference', label: _bigLabel);
  }

  @override
  void initState() {
    super.initState();
    _sipRef = context.read<SipProvider>();
    _mediaRef = context.read<MediaProvider>();
    _sipRef.addListener(_handleSipChange);
    _participants.addListener(_onParticipants);
    _participants.onResyncNeeded = _autoResync;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPolling());
  }

  final ConferenceParticipantService _participants = ConferenceParticipantService.instance;
  late final SipProvider _sipRef;
  late final MediaProvider _mediaRef;
  Timer? _resyncTimer;
  bool _syncing = false;

  /// 참가자 변화/원격 요청 → 1.5초 후 영상 동기화(연속 이벤트는 1회로 합침)
  void _autoResync(String reason) {
    _resyncTimer?.cancel();
    _resyncTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _mediaRef.resyncVideo(reason: 'auto:$reason');
    });
  }

  /// 수동: 전 참가자 영상 동기화
  Future<void> _syncAll() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final ok = await _participants.requestSyncAll();
    await _mediaRef.resyncVideo(reason: 'manual');
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(ok ? '전체 참가자 영상 동기화 요청' : '내 화면만 동기화(서버 응답 없음)'),
    ));
  }

  void _onParticipants() {
    if (mounted) setState(() {});
  }

  String get _myExtension => _sipRef.config?.username ?? '';

  String get _myLabel {
    final cfg = _sipRef.config;
    final ext = cfg?.username ?? '';
    final name = (cfg?.displayName ?? '').trim();
    final who = name.isEmpty || name == ext ? ext : '$name ($ext)';
    return who.isEmpty ? '나' : '나 · $who';
  }

  /// 회의 중일 때만 OPS 참가자 폴링
  void _syncPolling() {
    if (!mounted) return;
    final sp = _sipRef;
    final room = sp.currentCallTarget;
    if (sp.isInCall && room != null && RegExp(r'^\d{3,6}$').hasMatch(room)) {
      _participants.start(room, extension: _myExtension);
    } else {
      _participants.stop();
    }
  }

  @override
  void dispose() {
    _sipRef.removeListener(_handleSipChange);
    _resyncTimer?.cancel();
    if (_participants.onResyncNeeded == _autoResync) _participants.onResyncNeeded = null;
    _participants.removeListener(_onParticipants);
    _participants.stop();
    if (_fullscreen) WindowFullscreen.set(false, screen: 'conference');
    _roomController.dispose();
    super.dispose();
  }

  void _handleSipChange() {
    if (!mounted) return;
    _syncPolling();
    final sp = _sipRef;
    if (sp.isInCall) {
      _wasInCall = true;
    } else if (_wasInCall) {
      _wasInCall = false;
      if (_fullscreen) _setFullscreen(false);
      final nav = Navigator.of(context);
      if (widget.autoClose && nav.canPop()) {
        AppLogger.instance.ui('CONFERENCE', 'autoCloseOnCallEnd');
        nav.pop();
        return;
      }
    }

    final sipProvider = _sipRef;
    final mediaProvider = _mediaRef;

    for (final event in sipProvider.drainMediaEvents()) {
      mediaProvider.applySipMediaEvent(event, fallbackSession: 'conference');
    }
  }

  bool _joining = false;

  Future<void> _join() async {
    if (_joining) return;
    final sipProvider = context.read<SipProvider>();
    final mediaProvider = context.read<MediaProvider>();
    final room = _roomController.text.trim();

    if (room.isEmpty) return;
    if (sipProvider.isInCall) {
      AppLogger.instance.ui('CONFERENCE', 'joinSkipped',
          params: {'reason': 'alreadyInCall', 'room': room});
      return;
    }

    setState(() => _joining = true);
    try {
      AppLogger.instance.ui('CONFERENCE', 'joinPressed',
          params: {'room': room, 'registered': sipProvider.isRegistered});

      if (!mediaProvider.hasLocalStream) {
        AppLogger.instance.d('CONFERENCE: 로컬 미디어 없음 → getLocalMedia() 선행');
        await mediaProvider.getLocalMedia();
      }

      await sipProvider.call(room, mediaStream: mediaProvider.localStream);
      if (mounted && mediaProvider.lastMissingDevices.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('저장된 장치 없음: ${mediaProvider.lastMissingDevices.join(', ')} — 기본 장치 사용')));
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      } else {
        _joining = false;
      }
    }
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

    if (inConference && _fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildConferenceGrid(mediaProvider),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(inConference
            ? '회의실 ${sipProvider.currentCallTarget ?? ''}'
                '${_participants.snapshot != null ? ' · 참가자 ${_participants.snapshot!.count}명' : ''}'
                '${RegExp(r'^61\d\d$').hasMatch(sipProvider.currentCallTarget ?? '') ? ' · 발언자 화면' : ''}'
            : '회의실'),
        actions: [
          if (inConference)
            TextButton.icon(
              onPressed: _syncing ? null : _syncAll,
              icon: _syncing
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: const Text('영상 동기화'),
            ),
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
              onPressed: (sipProvider.isRegistered && !_joining && !sipProvider.isInCall)
                  ? _join
                  : null,
              icon: _joining
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(!sipProvider.isRegistered
                  ? 'SIP 미등록'
                  : sipProvider.isInCall
                      ? '통화 중'
                      : _joining
                          ? '참가 중...'
                          : '회의 참가'),
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
    final room = _sipRef.currentCallTarget ?? '';
    final followTalker = RegExp(r'^61\d\d$').hasMatch(room);
    final remotes = followTalker
        ? _buildTalkerTiles(mediaProvider, remoteStreams)
        : _buildRemoteTiles(mediaProvider, remoteStreams);
    final local = _ConferenceTile(
      label: _myLabel,
      renderer: mediaProvider.getLocalRenderer(),
      stream: mediaProvider.hasLocalVideo ? mediaProvider.localStream : null,
      mirror: true,
      isLocal: true,
    );

    if (_selectedRemote >= remotes.length) {
      _selectedRemote = remotes.isEmpty ? 0 : remotes.length - 1;
    }
    final showLocalBig = _selectedRemote < 0 || remotes.isEmpty;
    final big = showLocalBig ? local : remotes[_selectedRemote];
    _bigLabel = big.label;
    final bigView = remotes.isEmpty && !showLocalBig
        ? _waitingView()
        : _buildVideoTile(
            label: big.label,
            renderer: big.renderer,
            stream: big.stream,
            mirror: big.mirror,
            placeholder: big.placeholder,
          );

    if (_fullscreen) {
      return FullscreenStage(
        onExit: () => _setFullscreen(false),
        audioMuted: mediaProvider.isAudioMuted,
        onToggleAudio: () => mediaProvider.toggleAudio(),
        onHangup: () {
          _setFullscreen(false);
          _leave();
        },
        child: bigView,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Tooltip(
                    message: '더블클릭: 전체 화면',
                    waitDuration: const Duration(seconds: 1),
                    child: GestureDetector(
                      onDoubleTap: () => _setFullscreen(true),
                      child: bigView,
                    ),
                  ),
                ),
                Positioned(
                  right: showLocalBig ? 12 : 200,
                  top: 12,
                  child: IconButton(
                    tooltip: '전체 화면 (더블클릭)',
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () => _setFullscreen(true),
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
                        placeholder: local.placeholder,
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
                          params: {'index': i + 1, 'label': remotes[i].label});
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

  /// 참가자 카드 목록.
  /// - OPS 참가자 정보가 있으면: 서버 참가자 전원(본인 제외), 영상 있는 참가자는 원격 스트림과 매핑
  /// - 없으면: 원격 영상 트랙 기준(이전 동작)
  List<_ConferenceTile> _buildRemoteTiles(
      MediaProvider mediaProvider, List<MediaStream> remoteStreams) {
    final snap = _participants.snapshot;
    if (snap == null || snap.participants.isEmpty) {
      return [
        for (var i = 0; i < remoteStreams.length; i++)
          _ConferenceTile(
            label: '참가자 ${i + 1}',
            renderer: mediaProvider.getRemoteRenderer(i),
            stream: remoteStreams[i],
          ),
      ];
    }
    final others = snap.participants.where((p) => !p.isSelf).toList();
    final byChannel = {for (final p in others) p.channel: p};
    // 원격 스트림 순서 = 서버 영상 슬롯 순서. 영상 없는 슬롯이 트랙으로 오지 않은 경우를 위해
    // 스트림 개수와 맞는 순서를 고른다.
    final full = snap.videoOrder.where(byChannel.containsKey).toList();
    final withVideo = full.where((c) => byChannel[c]!.hasVideo).toList();
    final order = remoteStreams.length == full.length ? full : withVideo;
    final streamIndex = <String, int>{
      for (var i = 0; i < order.length && i < remoteStreams.length; i++) order[i]: i,
    };
    // 영상 있는 참가자 먼저(영상 순서), 그다음 영상 없는 참가자
    others.sort((a, b) {
      final ai = streamIndex[a.channel] ?? 1 << 20;
      final bi = streamIndex[b.channel] ?? 1 << 20;
      return ai.compareTo(bi);
    });
    final extCount = <String, int>{};
    for (final p in others) {
      extCount[p.extension] = (extCount[p.extension] ?? 0) + 1;
    }
    final seen = <String, int>{};
    return [
      for (final p in others)
        () {
          final n = (seen[p.extension] = (seen[p.extension] ?? 0) + 1);
          final label = (extCount[p.extension] ?? 0) > 1 ? '${p.label} #$n' : p.label;
          final idx = streamIndex[p.channel];
          final usable = p.hasVideo && idx != null;
          return _ConferenceTile(
            label: label,
            renderer: usable ? mediaProvider.getRemoteRenderer(idx) : null,
            stream: usable ? remoteStreams[idx] : null,
            hasVideo: p.hasVideo,
          );
        }(),
    ];
  }

  /// 6100대(follow_talker): 서버가 현재 발언자 영상 1개만 보낸다.
  /// 큰 화면 = "발언자 영상", 나머지 참가자는 목록 카드(영상 없음 표시 대신 이름만).
  List<_ConferenceTile> _buildTalkerTiles(
      MediaProvider mediaProvider, List<MediaStream> remoteStreams) {
    final snap = _participants.snapshot;
    final tiles = <_ConferenceTile>[
      _ConferenceTile(
        label: '발언자 영상',
        renderer: remoteStreams.isNotEmpty ? mediaProvider.getRemoteRenderer(0) : null,
        stream: remoteStreams.isNotEmpty ? remoteStreams.first : null,
      ),
    ];
    for (final p in (snap?.participants ?? const <ConferenceParticipant>[])) {
      if (p.isSelf) continue;
      tiles.add(_ConferenceTile(
        label: p.label,
        renderer: null,
        stream: null,
        hasVideo: false,
        participantOnly: true,
      ));
    }
    return tiles;
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
            placeholder: tile.placeholder,
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
    _Placeholder placeholder = _Placeholder.waiting,
  }) {
    final (IconData icon, String text) = switch (placeholder) {
      _Placeholder.noVideo => (Icons.mic, '영상 없음 · 음성 참여'),
      _Placeholder.noCamera => (Icons.videocam_off_outlined, '카메라 없음'),
      _Placeholder.waiting => (Icons.videocam_off_outlined, '영상 수신 준비중'),
      _Placeholder.participant => (Icons.record_voice_over, '발언 시 큰 화면 표시'),
    };
    return Container(
      decoration: BoxDecoration(
        color: placeholder == _Placeholder.noVideo && stream == null
            ? const Color(0xFF263238)
            : Colors.black,
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
                    Icon(icon, color: Colors.white70, size: compact ? 26 : 64),
                    SizedBox(height: compact ? 4 : 12),
                    Text(text,
                        style: TextStyle(
                            color: Colors.white70, fontSize: compact ? 11 : 16)),
                  ],
                ),
              ),
            // 참가자 이름/내선 — 큰 화면·작은 카드 모두 항상 표시
            Positioned(
              left: compact ? 6 : 12,
              top: compact ? 6 : 12,
              right: compact ? 6 : null,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 12, vertical: compact ? 3 : 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: compact ? 13 : 20),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 12 : 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Placeholder { waiting, noVideo, noCamera, participant }

class _ConferenceTile {
  const _ConferenceTile({
    required this.label,
    required this.renderer,
    required this.stream,
    this.mirror = false,
    this.hasVideo = true,
    this.isLocal = false,
    this.participantOnly = false,
  });

  /// 6100 참가자 목록 카드(영상은 발언자 화면에서만)
  final bool participantOnly;

  final String label;
  final RTCVideoRenderer? renderer;
  final MediaStream? stream;
  final bool mirror;
  final bool hasVideo;
  final bool isLocal;

  _Placeholder get placeholder => isLocal
      ? _Placeholder.noCamera
      : participantOnly
          ? _Placeholder.participant
          : (hasVideo ? _Placeholder.waiting : _Placeholder.noVideo);
}
