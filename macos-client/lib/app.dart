import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'src/ui/login/login_screen.dart';
import 'src/ui/dialer/dialer_screen.dart';
import 'src/ui/call/call_screen.dart';
import 'src/ui/conference/conference_screen.dart';
import 'src/ui/media/media_test_screen.dart';

final _router = GoRouter(
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
      builder: (context, state) => const ConferenceView(),
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

class KibalApp extends StatelessWidget {
  const KibalApp({super.key});

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
