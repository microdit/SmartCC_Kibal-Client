import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_logger.dart';

/// 저장된 미디어 장치 1개 (id 우선, USB 재연결로 id가 바뀌면 label로 매칭)
class SavedDevice {
  const SavedDevice(this.id, this.label);
  final String id;
  final String label;

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
  static SavedDevice? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return SavedDevice(id, (j['label'] as String?) ?? '');
  }
}

/// 미디어 장치 선택 저장/해석 (A10 USB 등 외부 장치 고정 사용)
/// 파일: `<logs>/media-devices.json`
class MediaDeviceSettings {
  MediaDeviceSettings._();
  static final MediaDeviceSettings instance = MediaDeviceSettings._();

  SavedDevice? camera;
  SavedDevice? mic;
  SavedDevice? speaker;
  bool _loaded = false;

  static String get filePath => '${AppLogger.logDirectory}/media-devices.json';

  /// 회의실 장비 추천(Yealink/A10/MeetingBar)
  static bool isRecommended(String label) =>
      RegExp(r'yealink|meetingbar|a10', caseSensitive: false).hasMatch(label);

  void load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = File(filePath);
      if (!f.existsSync()) return;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      camera = SavedDevice.fromJson(j['camera']);
      mic = SavedDevice.fromJson(j['mic']);
      speaker = SavedDevice.fromJson(j['speaker']);
    } catch (e) {
      AppLogger.instance.w('장치 설정 읽기 실패: $e');
    }
  }

  void save({SavedDevice? camera, SavedDevice? mic, SavedDevice? speaker}) {
    this.camera = camera;
    this.mic = mic;
    this.speaker = speaker;
    try {
      File(filePath).writeAsStringSync(jsonEncode({
        'camera': camera?.toJson(),
        'mic': mic?.toJson(),
        'speaker': speaker?.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      }));
      AppLogger.instance.i('MEDIA device saved camera=${camera?.label ?? '기본'} '
          'mic=${mic?.label ?? '기본'} speaker=${speaker?.label ?? '기본'}');
    } catch (e) {
      AppLogger.instance.w('장치 설정 저장 실패: $e');
    }
  }

  /// 현재 연결된 장치 중 저장값과 맞는 deviceId. 없으면 null(기본 장치).
  static String? resolve(SavedDevice? saved, List<MediaDeviceInfo> devices, String kind) {
    if (saved == null) return null;
    final list = devices.where((d) => d.kind == kind).toList();
    for (final d in list) {
      if (d.deviceId == saved.id) return d.deviceId;
    }
    if (saved.label.isNotEmpty) {
      for (final d in list) {
        if (d.label == saved.label) return d.deviceId;
      }
    }
    return null;
  }

  /// 통화용 장치 해석 결과 + 미존재 경고
  Future<({String? cameraId, String? micId, String? speakerId, List<String> missing})>
      resolveForCall() async {
    load();
    List<MediaDeviceInfo> devices = const [];
    try {
      devices = await navigator.mediaDevices.enumerateDevices();
    } catch (_) {}
    final missing = <String>[];
    String? pick(SavedDevice? s, String kind, String name) {
      final id = resolve(s, devices, kind);
      if (s != null && id == null) missing.add('$name(${s.label})');
      return id;
    }

    final r = (
      cameraId: pick(camera, 'videoinput', '카메라'),
      micId: pick(mic, 'audioinput', '마이크'),
      speakerId: pick(speaker, 'audiooutput', '스피커'),
      missing: missing,
    );
    AppLogger.instance.i('MEDIA device resolve camera=${r.cameraId ?? '기본'} '
        'mic=${r.micId ?? '기본'} speaker=${r.speakerId ?? '기본'}'
        '${missing.isEmpty ? '' : ' missing=${missing.join(',')}'}');
    return r;
  }
}
