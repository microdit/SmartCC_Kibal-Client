import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'src/ui/login/login_screen.dart';
import 'src/ui/dialer/dialer_screen.dart';
import 'src/ui/call/call_screen.dart';
import 'src/ui/conference/conference_screen.dart';

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
  ],
);

class KibalApp extends StatelessWidget {
  const KibalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kibal macOS',
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
