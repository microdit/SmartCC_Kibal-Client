import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'src/providers/sip_provider.dart';
import 'src/providers/media_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 강제 세로 모드 (영상통화 시 현재의 고정)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 시스템 UI 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
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
