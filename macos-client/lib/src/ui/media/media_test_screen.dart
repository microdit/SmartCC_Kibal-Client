import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../providers/media_provider.dart';
import '../../utils/app_logger.dart';

class DeviceInfo {
  DeviceInfo({required this.id, required this.name, this.kind});
  final String id;
  final String name;
  final String? kind;
}

/// 미디어 테스트 화면: 카메라/마이크 선택 + 자체 테스트(프리뷰/레벨 미터) + 감도
class MediaTestScreen extends StatefulWidget {
  const MediaTestScreen({super.key});

  @override
  State<MediaTestScreen> createState() => _MediaTestScreenState();
}

class _MediaTestScreenState extends State<MediaTestScreen> {
  static const _channel = MethodChannel('kibal/media_test');

  final _camRenderer = RTCVideoRenderer();

  List<DeviceInfo> _mics = [];
  List<DeviceInfo> _cams = [];
  String? _camDeviceId;
  String? _micDeviceId;

  bool _meterRunning = false;
  double _avgDb = -160;
  double _peakDb = -160;
  double _gain = 1.0; // 마이크 감도 계수 (표시/전송 레벨 배율)
  bool _camOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _camRenderer.initialize();
      await _loadDevices();
      await _startCameraTest();
      if (mounted) setState(() {});
    });
    AppLogger.instance.ui('MEDIA_TEST', 'screenOpened');
  }

  Future<void> _loadDevices() async {
    try {
      final results =
          await navigator.mediaDevices.enumerateDevices();
      final cams = <DeviceInfo>[];
      final mics = <DeviceInfo>[];
      for (final d in results) {
        final kind = d.kind;
        final label = d.label;
        final name = label.isNotEmpty
            ? label
            : (kind == 'audioinput' ? '마이크(기본)' : '카메라(기본)');
        if (kind == 'audioinput') {
          mics.add(
              DeviceInfo(id: d.deviceId, name: name, kind: kind));
        } else if (kind == 'videoinput') {
          cams.add(
              DeviceInfo(id: d.deviceId, name: name, kind: kind));
        }
      }
      if (!mounted) return;
      setState(() {
        _mics = mics;
        _cams = cams;
        if (_mics.isNotEmpty) _micDeviceId ??= _mics.first.id;
        if (_cams.isNotEmpty) _camDeviceId ??= _cams.first.id;
      });
      AppLogger.instance
          .evt('MEDIA_TEST', 'devicesLoaded', details: {'mics': mics.length, 'cams': cams.length});
    } catch (e) {
      AppLogger.instance.e('MEDIA_TEST 디바이스 열거 실패: $e');
    }

    // 네이티브 카메라 목록(보조 정보)
    try {
      final nativeCams = await _channel.invokeListMethod<Map>('listCameras');
      // WebRTC용 deviceId와 불일치할 수 있으므로 로그만 남김
      AppLogger.instance.d('native cameras: ${nativeCams?.length ?? 0}');
    } catch (_) {}
  }

  Future<void> _startCameraTest() async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    AppLogger.instance.ui('MEDIA_TEST', 'cameraTestStart',
        params: {'deviceId': _camDeviceId});
    await mediaProvider.getLocalMedia(videoDeviceId: _camDeviceId, micDeviceId: null);
    _camRenderer.srcObject = mediaProvider.localStream;
    if (mounted) setState(() => _camOn = true);
  }

  Future<void> _toggleMeter() async {
    AppLogger.instance.ui('MEDIA_TEST', _meterRunning ? 'meterStopPressed' : 'meterStartPressed');
    try {
      if (_meterRunning) {
        await _channel.invokeMethod('stopMicMeter');
      } else {
        await _channel.invokeMethod('startMicMeter');
      }
      if (mounted) setState(() => _meterRunning = !_meterRunning);
    } on PlatformException catch (e) {
      AppLogger.instance.e('MEDIA_TEST meter 오류: ${e.message}');
      if (mounted) setState(() {});
    }
  }

  Future<void> _pollLevels() async {
    if (!_meterRunning) return;
    try {
      final res = await _channel
          .invokeMapMethod<String, double>('readMicLevels');
      if (res != null && mounted) {
        setState(() {
          _avgDb = res['avg'] ?? -160;
          _peakDb = res['peak'] ?? -160;
        });
      }
    } catch (_) {}
  }

  Future<void> _applyMicChange(String? deviceId) async {
    setState(() => _micDeviceId = deviceId);
    AppLogger.instance.ui('MEDIA_TEST', 'micDeviceSelected',
        params: {'deviceId': deviceId});
    if (_meterRunning) await _toggleMeter();
  }

  Future<void> _applyCamChange(String? deviceId) async {
    setState(() => _camDeviceId = deviceId);
    AppLogger.instance.ui('MEDIA_TEST', 'cameraDeviceSelected',
        params: {'deviceId': deviceId});
    await _startCameraTest();
  }

  String get meterSummary =>
      'avg=$_avgDb, peak=$_peakDb, gain=x${_gain.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    _pollLevels(); // 폴링 (간단 구현)
    final mediaProvider = Provider.of<MediaProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dialer'),
        ),
        title: const Text('미디어 테스트'),
        actions: [
          TextButton(
            onPressed: _toggleMeter,
            child: Text(_meterRunning ? '미터 정지' : '마이크 테스트 시작'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMicTestSection(),
          const SizedBox(height: 24),
          _buildCameraTestSection(mediaProvider),
          const SizedBox(height: 24),
          // 디스플레이 메타마크
          _buildDevicePickerSection(),
        ],
      ),
    );
  }

  Widget _buildMicTestSection() {
    double avgAlt = (((_avgDb + 60) / 60).clamp(0, 1).toDouble()) * _gain;
    double peakAlt = (((_peakDb + 60) / 60).clamp(0, 1).toDouble()) * _gain;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('마이크 레벨 미터',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('avg=${_avgDb.toStringAsFixed(1)}dB  peak=${_peakDb.toStringAsFixed(1)}dB',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          if (_meterRunning) ...[
            LinearProgressIndicator(
              value: avgAlt.clamp(0, 1),
              color: Colors.blue,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: peakAlt.clamp(0, 1),
              color: Colors.green,
              minHeight: 10,
            ),
            const Text('파란=평균, 초록=피크 (60dB~0dB)', style: TextStyle(fontSize: 11)),
          ] else
            const Text('미터 꺼짐 — 메뉴의 "마이크 테스트 시작"으로 켜세요',
                style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('감도(게인)'),
            Expanded(
              child: Slider(
                value: _gain,
                min: 0.5,
                max: 4.0,
                divisions: 70,
                label: _gain.toStringAsFixed(1),
                onChanged: (v) {
                  AppLogger.instance.ui('MEDIA_TEST', 'gainChanged',
                      params: {'value': v.toStringAsFixed(2)});
                  setState(() => _gain = v);
                  _applyGain();
                },
              ),
            ),
            Text('x${_gain.toStringAsFixed(1)}'),
          ]),
        ]),
      ),
    );
  }

  /// 게인 반영 (setVolume 미지원이면 표시용으로만 사용)
  Future<void> _applyGain() async {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    try {
      final stream = mediaProvider.localStream;
      if (stream == null) return;
      final method = trackSetVolumeSupported();
      AppLogger.instance.evt('MEDIA_TEST', 'micGainNote',
          state: 'gain=$_gain supported=$method');
    } catch (e) {
      AppLogger.instance.w('마이크 게인 적용 미지원: $e');
    }
  }

  bool trackSetVolumeSupported() => false;

  Widget _buildCameraTestSection(MediaProvider mediaProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('카메라 프리뷰',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _camOn
                ? Container(
                    color: Colors.black,
                    child: RTCVideoView(_camRenderer, mirror: true))
                : Container(
                    color: Colors.black,
                    child: const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white54))),
          ),
        ]),
      ),
    );
  }

  Widget _buildDevicePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('디바이스 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('마이크', style: TextStyle(fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            isExpanded: true,
            value: _micDeviceId,
            hint: const Text('마이크 선택'),
            items: _mics
                .map((d) => DropdownMenuItem(
                      key: Key('mic_${d.id}'),
                      value: d.id,
                      child: Text(d.name),
                    ))
                .toList(),
            onChanged: _applyMicChange,
          ),
          const Text('카메라', style: TextStyle(fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            isExpanded: true,
            value: _camDeviceId,
            hint: const Text('카메라 선택'),
            items: _cams
                .map((d) => DropdownMenuItem(
                      key: Key('cam_${d.id}'),
                      value: d.id,
                      child: Text(d.name),
                    ))
                .toList(),
            onChanged: _applyCamChange,
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    if (_meterRunning) {
      _channel.invokeMethod('stopMicMeter').catchError((_) {});
    }
    _camRenderer.srcObject = null;
    _camRenderer.dispose();
    super.dispose();
  }
}
