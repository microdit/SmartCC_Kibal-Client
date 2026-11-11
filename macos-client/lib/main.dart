import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'src/providers/sip_provider.dart';
import 'src/providers/media_provider.dart';
import 'src/utils/app_logger.dart';
import 'src/utils/remote_log_forwarder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();
  AppLogger.instance.hookGlobalErrors();

  // 로그 자동 수집: 로컬 app.log와 동일한 라인을 OPS 콘솔로 실시간 배출.
  // 로그인 성공 시 내선 번호(extension)와 도메인이 갱신된다.
  // 사용자 설정(remote-log-settings.json)의 모드/서버 주소를 따른다.
  unawaited(RemoteLogForwarder.instance.start());

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
