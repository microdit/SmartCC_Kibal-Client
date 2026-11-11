import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'src/providers/media_provider.dart';
import 'src/providers/sip_provider.dart';
import 'src/ui/login/login_screen.dart';
import 'src/ui/dialer/dialer_screen.dart';
import 'src/ui/call/call_screen.dart';
import 'src/ui/conference/conference_screen.dart';
import 'src/ui/media/media_test_screen.dart';
import 'src/utils/app_logger.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dialer',
      builder: (context, state) => const DialerScreen(),
    ),
    GoRoute(
      path: '/call',
      builder: (context, state) =>
          CallScreen(target: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: '/conference',
      builder: (context, state) => const ConferenceView(autoClose: true),
    ),
    GoRoute(
      path: '/mediaTest',
      builder: (context, state) => const MediaTestScreen(),
    ),
  ],
);

/// 빌드 시 dart-define으로 주입되는 버전 (scripts/build_macos.sh 참조)
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'v-dev');

class KibalApp extends StatefulWidget {
  const KibalApp({super.key});

  @override
  State<KibalApp> createState() => _KibalAppState();
}

class _KibalAppState extends State<KibalApp> {
  bool _incomingDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // D-Ux: 수신 다이얼로그가 특정 화면(MacMainView)에만 묶여 있어 수신을 수락할
    // 방법이 없던 문제 → 앱 최상위(어느 화면에서든)에 전역 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SipProvider>().addListener(_handleIncomingCall);
    });
  }

  @override
  void dispose() {
    Provider.of<SipProvider>(context, listen: false)
        .removeListener(_handleIncomingCall);
    super.dispose();
  }

  void _handleIncomingCall() {
    final sipProvider = Provider.of<SipProvider>(context, listen: false);
    final navigator = _rootNavigatorKey.currentState;
    if (navigator == null) return;
    if (!sipProvider.hasIncomingCall) {
      if (_incomingDialogShowing) {
        // B2: 이 State의 context는 MaterialApp.router 위에 있어 Navigator가 없다.
        // 이미 확보한 루트 네비게이터로 닫는다.
        navigator.maybePop();
        _incomingDialogShowing = false;
      }
      return;
    }
    if (_incomingDialogShowing) return;
    _incomingDialogShowing = true;

    final target = sipProvider.currentCallTarget ?? '알 수 없음';
    AppLogger.instance.ui('INCOMING', 'dialogShown', params: {'target': target});

    navigator.push(DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수신 통화'),
        content: Text('$target 님으로부터 통화가 왔습니다.'),
        actions: [
          TextButton(
            onPressed: () async {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              await sipProvider.reject();
              AppLogger.instance
                  .ui('INCOMING', 'rejected', params: {'target': target});
            },
            child: const Text('거부', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () async {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              final rootCtx = _rootNavigatorKey.currentContext;
              final mediaProvider = rootCtx == null
                  ? null
                  : Provider.of<MediaProvider>(rootCtx, listen: false);
              if (mediaProvider != null && !mediaProvider.hasLocalStream) {
                await mediaProvider.getLocalMedia();
              }
              final ok = await sipProvider.accept(
                mediaStream: mediaProvider?.localStream,
              );
              AppLogger.instance.ui('INCOMING', 'accepted',
                  params: {'target': target, 'ok': ok});
              if (ok) _router.push('/call', extra: target);
            },
            child: const Text('수락'),
          ),
        ],
      ),
    )).then((_) => _incomingDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kibal macOS $kAppVersion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      routerConfig: _router,
    );
  }
}
