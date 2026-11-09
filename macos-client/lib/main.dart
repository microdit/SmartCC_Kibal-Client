import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'src/providers/sip_provider.dart';
import 'src/providers/media_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
