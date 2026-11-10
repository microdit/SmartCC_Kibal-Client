import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'src/providers/sip_provider.dart';
import 'src/providers/media_provider.dart';
import 'src/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();
  AppLogger.instance.hookGlobalErrors();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SipProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider()),
      ],
      child: const KibalApp(),
    ),
  );
}
