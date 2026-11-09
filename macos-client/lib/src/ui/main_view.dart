import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/sip_provider.dart';
import '../providers/media_provider.dart';
import 'dialer/dialer_screen.dart';
import 'conference/conference_screen.dart';

class _TrafficLight extends StatelessWidget {
  final Color color;
  const _TrafficLight(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// macOS 데스크톱 셸 (TitleBar + Sidebar + Content)
///
/// 앱 라우팅은 GoRouter를 사용하며, 본 위젯은 데스크톱 레이아웃이
/// 필요한 화면에서 사용할 수 있는 대체 셸이다.
class MacMainView extends StatefulWidget {
  const MacMainView({super.key});

  @override
  State<MacMainView> createState() => _MacMainViewState();
}

class _MacMainViewState extends State<MacMainView> {
  int _selectedIndex = 0;
  bool _incomingDialogShowing = false;

  @override
  void initState() {
    super.initState();
    context.read<SipProvider>().addListener(_handleIncomingCall);
  }

  @override
  void dispose() {
    context.read<SipProvider>().removeListener(_handleIncomingCall);
    super.dispose();
  }

  /// 수신 통화 알림 표시
  void _handleIncomingCall() {
    final sipProvider = context.read<SipProvider>();

    if (!sipProvider.hasIncomingCall) {
      if (_incomingDialogShowing && mounted) {
        _incomingDialogShowing = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }

    if (_incomingDialogShowing || !mounted) return;
    _incomingDialogShowing = true;

    final target = sipProvider.currentCallTarget ?? '알 수 없음';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수신 통화'),
        content: Text('$target 님으로부터 영상통화가 왔습니다.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await sipProvider.reject();
            },
            child: const Text('거부', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final mediaProvider = context.read<MediaProvider>();
              if (!mediaProvider.hasLocalStream) {
                await mediaProvider.getLocalMedia();
              }

              final ok = await sipProvider.accept(
                mediaStream: mediaProvider.localStream,
              );

              if (ok && mounted) {
                context.push('/call', extra: target);
              }
            },
            child: const Text('수락'),
          ),
        ],
      ),
    ).then((_) => _incomingDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final sipProvider = context.watch<SipProvider>();
    final mediaProvider = context.watch<MediaProvider>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(36.0),
        child: Container(
          height: 36.0,
          color: Colors.blue[800],
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TrafficLight(Colors.red),
                    SizedBox(width: 4),
                    _TrafficLight(Colors.yellow),
                    SizedBox(width: 4),
                    _TrafficLight(Colors.green),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  sipProvider.isRegistered
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {},
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                onPressed: () {},
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          Container(
            width: 220,
            color: Colors.grey[200],
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('내선'),
                  subtitle: Text(sipProvider.config?.username ?? '1101'),
                ),
                ListTile(
                  leading: Icon(
                    mediaProvider.isVideoMuted
                        ? Icons.videocam_off
                        : Icons.videocam,
                    color: mediaProvider.isVideoMuted
                        ? Colors.red
                        : Colors.green,
                    size: 20,
                  ),
                  title: const Text('카메라'),
                  trailing: Switch(
                    value: !mediaProvider.isVideoMuted,
                    onChanged: (_) => mediaProvider.toggleVideo(),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    mediaProvider.isAudioMuted ? Icons.mic_off : Icons.mic,
                    color: mediaProvider.isAudioMuted
                        ? Colors.red
                        : Colors.green,
                    size: 20,
                  ),
                  title: const Text('마이크'),
                  trailing: Switch(
                    value: !mediaProvider.isAudioMuted,
                    onChanged: (_) => mediaProvider.toggleAudio(),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dialpad),
                  title: const Text('다이얼러'),
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: const Text('회의실'),
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: () async {
                    await sipProvider.unregister();
                    await sipProvider.disconnect();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                DialerScreen(),
                ConferenceView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
