import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_logger.dart';

enum VideoQualityMode { auto, r320, r640, r720, r1080, r2160 }

class VideoQualitySettings {
  VideoQualitySettings(this.mode, {this.frameRate = 30});

  final VideoQualityMode mode;
  final int frameRate;
  static const filePath = 'video-quality-settings.json';

  static String get filePathFull => '${AppLogger.logDirectory}/$filePath';

  factory VideoQualitySettings.load() {
    try {
      final file = File(filePathFull);
      if (!file.existsSync()) return VideoQualitySettings(VideoQualityMode.auto);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = json['mode'] as String? ?? 'auto';
      return VideoQualitySettings(
        VideoQualityMode.values.firstWhere(
          (m) => m.name == name,
          orElse: () => VideoQualityMode.auto,
        ),
        frameRate: (json['frameRate'] as num?)?.toInt() ?? 30,
      );
    } catch (_) {
      return VideoQualitySettings(VideoQualityMode.auto);
    }
  }

  void save() {
    try {
      File(filePathFull)
          .writeAsStringSync(jsonEncode({'mode': mode.name, 'frameRate': frameRate}));
    } catch (e) {
      AppLogger.instance.w('영상 품질 설정 저장 실패: $e');
    }
  }

  bool get isAuto => mode == VideoQualityMode.auto;

  int? get width {
    switch (mode) {
      case VideoQualityMode.r320:
        return 568;
      case VideoQualityMode.r640:
        return 640;
      case VideoQualityMode.r720:
        return 1280;
      case VideoQualityMode.r1080:
        return 1920;
      case VideoQualityMode.r2160:
        return 3840;
      case VideoQualityMode.auto:
        return null;
    }
  }

  int? get height {
    switch (mode) {
      case VideoQualityMode.r320:
        return 320;
      case VideoQualityMode.r640:
        return 360;
      case VideoQualityMode.r720:
        return 720;
      case VideoQualityMode.r1080:
        return 1080;
      case VideoQualityMode.r2160:
        return 2160;
      case VideoQualityMode.auto:
        return null;
    }
  }

  int? get maxBitrate {
    switch (mode) {
      case VideoQualityMode.r320:
        return 400 * 1000;
      case VideoQualityMode.r640:
        return 800 * 1000;
      case VideoQualityMode.r720:
        return 2500 * 1000;
      case VideoQualityMode.r1080:
        return 5000 * 1000;
      case VideoQualityMode.r2160:
        return 12000 * 1000;
      case VideoQualityMode.auto:
        return null;
    }
  }

  RTCDegradationPreference get degradationPreference {
    if (isAuto) return RTCDegradationPreference.BALANCED;
    return RTCDegradationPreference.MAINTAIN_FRAMERATE_AND_RESOLUTION;
  }

  int? get maxFramerate => isAuto ? null : frameRate;

  VideoQualitySettings copyWith({
    VideoQualityMode? mode,
    int? frameRate,
  }) =>
      VideoQualitySettings(
        mode ?? this.mode,
        frameRate: frameRate ?? this.frameRate,
      );

  String get label {
    switch (mode) {
      case VideoQualityMode.auto:
        return '자동 (WebRTC 최적화)';
      case VideoQualityMode.r320:
        return '수동 320p';
      case VideoQualityMode.r640:
        return '수동 640p';
      case VideoQualityMode.r720:
        return '수동 720p';
      case VideoQualityMode.r1080:
        return '수동 1080p';
      case VideoQualityMode.r2160:
        return '수동 4K (2160p)';
    }
  }

  String get detail {
    if (isAuto) return '네트워크에 맞춰 WebRTC가 해상도·비트레이트를 조절합니다.';
    return '카메라 ${width}x$height @ ${frameRate}fps · '
        '최대 ${(maxBitrate! / 1000000).toStringAsFixed(1)}Mbps · 해상도/프레임 고정';
  }

  Map<String, dynamic> toJson() => {'mode': mode.name, 'frameRate': frameRate};
}
