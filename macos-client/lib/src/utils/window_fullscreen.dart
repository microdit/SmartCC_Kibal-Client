import 'package:flutter/services.dart';

import 'app_logger.dart';

/// macOS 창 전체 화면 제어 (MainFlutterWindow.swift `kibal/window`)
class WindowFullscreen {
  WindowFullscreen._();
  static const MethodChannel _ch = MethodChannel('kibal/window');

  /// 창 전체 화면 진입/해제. 실패해도 앱 내부 확장 레이아웃은 동작한다.
  static Future<void> set(bool value, {String screen = '-', String label = '-'}) async {
    AppLogger.instance.ui('VIDEO', value ? 'fullscreenEnter' : 'fullscreenExit',
        params: {'screen': screen, 'label': label});
    try {
      await _ch.invokeMethod<bool>('setFullScreen', value);
    } catch (e) {
      AppLogger.instance.w('창 전체 화면 전환 실패: $e');
    }
  }
}
