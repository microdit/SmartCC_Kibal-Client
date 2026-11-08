import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/providers/sip_provider.dart';
import 'src/providers/media_provider.dart';
import 'src/ui/main_view.dart';

class KibalApp extends StatelessWidget {
  const KibalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SipProvider>(
      builder: (context, sipProvider, child) {
        // SIP 등록 상태에 따른 초기 화면 변경
        if (!sipProvider.isRegistered) {
          return const LoginView();
        }
        return const MacMainView();
      },
    );
  }
}
