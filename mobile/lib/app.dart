import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'src/ui/login/login_screen.dart';
import 'src/ui/dialer/dialer_screen.dart';
import 'src/ui/call/call_screen.dart';

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
      builder: (context, state) => CallScreen(
        target: state.extra as String? ?? '',
      ),
    ),
  ],
);

class KibalApp extends StatelessWidget {
  const KibalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kibal Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
