class _TrafficLight extends StatelessWidget {
  final String color;
  const _TrafficLight(this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == 'red' ? Colors.red : color == 'yellow' ? Colors.yellow : Colors.green,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sip_provider.dart';
import '../providers/media_provider.dart';
import 'login/login_screen.dart';
import 'dialer/dialer_screen.dart';
import 'call/call_screen.dart';
import 'conference/conference_screen.dart';

class MacMainView extends StatelessWidget {
  const MacMainView({super.key});

  @override
  Widget build(BuildContext context) {
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
                    _TrafficLight('red'),
                    SizedBox(width: 4),
                    _TrafficLight('yellow'),
                    SizedBox(width: 4),
                    _TrafficLight('green'),
                  ],
                ),
              ),
              Spacer(),
              Consumer<SipProvider>(
                builder: (context, provider, child) {
                  return IconButton(
                    icon: provider.isRegistered
                        ? const Icon(Icons.notifications_active, color: Colors.white, size: 18)
                        : const Icon(Icons.notifications_off, color: Colors.white, size: 18),
                    onPressed: () {},
                    iconSize: 18,
                    padding: EdgeInsets.all(2),
                  );
                },
              ),
              SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                onPressed: () {},
                padding: EdgeInsets.all(2),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 18),
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginView()),
                      (route) => false,
                    );
                  }
                },
                iconSize: 16,
                padding: EdgeInsets.all(2),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          Container(
            width: 200,
            color: Colors.grey[200],
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('내선 선택'),
                  subtitle: Text('현재: ${Provider.of<SipProvider>(context, listen: false).config?.username ?? "1101"}'),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () {},
                ),
                ListTile(
                  leading: Consumer<MediaProvider>(
                    builder: (ctx, m, _) => m.isCameraEnabled
                        ? const Icon(Icons.camera_alt, color: Colors.green, size: 20)
                        : const Icon(Icons.camera_alt, color: Colors.red, size: 20),
                  ),
                  title: const Text('카메라'),
                  trailing: Switch(
                    value: Provider.of<MediaProvider>(context, listen: false).isCameraEnabled,
                    onChanged: (v) => Provider.of<MediaProvider>(context, listen: false).toggleCamera(),
                  ),
                ),
                ListTile(
                  leading: Consumer<MediaProvider>(
                    builder: (ctx, m, _) => m.isMicEnabled
                        ? const Icon(Icons.mic, color: Colors.green, size: 20)
                        : const Icon(Icons.mic_off, color: Colors.red, size: 20),
                  ),
                  title: const Text('마이크'),
                  trailing: Switch(
                    value: Provider.of<MediaProvider>(context, listen: false).isMicEnabled,
                    onChanged: (v) => Provider.of<MediaProvider>(context, listen: false).toggleMic(),
                  ),
                ),
                Consumer<SipProvider>(
                  builder: (ctx, s, _) => s.isRegistered
                      ? ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('로그아웃'),
                          onTap: () => s.logout(),
                        )
                      : ListTile(
                          leading: const Icon(Icons.login),
                          title: const Text('로그인/등록'),
                          onTap: () => Navigator.pushNamed(ctx, '/login'),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Navigator(
              key: PageStorageKey<String>('macos-main-nav'),
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/login':
                    return MaterialPageRoute(builder: (_) => const LoginView());
                  case '/dialer':
                    return MaterialPageRoute(builder: (_) => const DialerView());
                  case '/call':
                    return MaterialPageRoute(builder: (_) => const CallView());
                  case '/conference':
                    return MaterialPageRoute(builder: (_) => const ConferenceView());
                  default:
                    return MaterialPageRoute(builder: (_) => const LoginView());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}